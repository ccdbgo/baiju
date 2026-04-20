import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/schedule_dao.dart';
import 'package:baiju_app/core/notifications/reminder_scheduler.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class ScheduleRepository {
  ScheduleRepository(
    this._database,
    this._dao, {
    ReminderScheduler? reminderScheduler,
    UserWorkspace? workspace,
    Uuid? uuid,
  })  : _reminderScheduler = reminderScheduler ?? const NoopReminderScheduler(),
        _workspace = workspace ?? const UserWorkspace.local(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ScheduleDao _dao;
  final ReminderScheduler _reminderScheduler;
  final UserWorkspace _workspace;
  final Uuid _uuid;

  Stream<List<SchedulesTableData>> watchSchedules(ScheduleFilter filter) {
    return _dao.watchSchedules(filter);
  }

  Future<SchedulesTableData> createSchedule({
    required String title,
    required QuickScheduleDay day,
    required QuickScheduleSlot slot,
    required ScheduleDurationOption duration,
    required ScheduleReminderOption reminder,
    ScheduleRecurrenceRule recurrence = ScheduleRecurrenceRule.none,
    String? description,
    String? location,
    String? category,
    bool isAllDay = false,
    String? sourceTodoId,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final scheduleId = _uuid.v4();
    final localNow = DateTime.now();
    final baseDate = DateTime(
      localNow.year,
      localNow.month,
      localNow.day + day.offsetDays,
    );
    final localStart = isAllDay
        ? baseDate
        : DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            slot.hour,
          );
    final localEnd = isAllDay
        ? baseDate.add(const Duration(days: 1))
        : localStart.add(Duration(minutes: duration.minutes));
    final startAt = localStart.toUtc();
    final endAt = localEnd.toUtc();
    final timezone = DateTime.now().timeZoneName;
    final normalizedTitle = title.trim();
    final normalizedDescription = _normalizeOptionalText(description);
    final normalizedLocation = _normalizeOptionalText(location);
    final normalizedCategory = _normalizeOptionalText(category);
    final recurrenceRule = ScheduleRecurrenceRule.normalizeRule(
      recurrence.rule,
    );

    final companion = SchedulesTableCompanion.insert(
      id: scheduleId,
      userId: _workspace.userId,
      title: normalizedTitle,
      description: Value(normalizedDescription),
      startAt: startAt,
      endAt: endAt,
      isAllDay: Value(isAllDay),
      timezone: Value(timezone),
      location: Value(normalizedLocation),
      category: Value(normalizedCategory),
      recurrenceRule: Value(recurrenceRule),
      reminderMinutesBefore: Value(reminder.minutes),
      sourceTodoId: Value(sourceTodoId),
      createdAt: Value(nowUtc),
      updatedAt: Value(nowUtc),
      syncStatus: const Value('pending_create'),
      localVersion: const Value(1),
      deviceId: Value(_workspace.deviceId),
    );

    final schedule = SchedulesTableData(
      id: scheduleId,
      userId: _workspace.userId,
      title: normalizedTitle,
      description: normalizedDescription,
      startAt: startAt,
      endAt: endAt,
      isAllDay: isAllDay,
      timezone: timezone,
      location: normalizedLocation,
      category: normalizedCategory,
      color: null,
      status: 'planned',
      recurrenceRule: recurrenceRule,
      reminderMinutesBefore: reminder.minutes,
      sourceTodoId: sourceTodoId,
      linkedNoteId: null,
      completedAt: null,
      createdAt: nowUtc,
      updatedAt: nowUtc,
      deletedAt: null,
      syncStatus: 'pending_create',
      localVersion: 1,
      remoteVersion: null,
      lastSyncedAt: null,
      deviceId: _workspace.deviceId,
    );

    await _database.transaction(() async {
      await _dao.insertSchedule(companion);
      await _enqueueSync(
        entityId: scheduleId,
        operation: 'create',
        payload: <String, Object?>{
          'id': scheduleId,
          'title': normalizedTitle,
          ..._scheduleMetadataPayload(
            description: normalizedDescription,
            location: normalizedLocation,
            category: normalizedCategory,
            isAllDay: isAllDay,
          ),
          'start_at': startAt.toIso8601String(),
          'end_at': endAt.toIso8601String(),
          'status': 'planned',
          'recurrence_rule': recurrenceRule,
          'reminder_minutes_before': reminder.minutes,
          'source_todo_id': sourceTodoId,
          'updated_at': nowUtc.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        sourceEntityId: scheduleId,
        action: 'created',
        title: normalizedTitle,
        summary: 'Created a schedule item',
        occurredAt: nowUtc,
        recurrenceRule: recurrenceRule,
        description: normalizedDescription,
        location: normalizedLocation,
        category: normalizedCategory,
        isAllDay: isAllDay,
      );
    });

    await _reminderScheduler.syncScheduleReminder(schedule);
    return schedule;
  }

  Future<void> toggleScheduleCompletion(
    SchedulesTableData schedule,
    bool completed,
  ) async {
    final nowUtc = DateTime.now().toUtc();
    final nextStatus = completed ? 'completed' : 'planned';
    final nextVersion = schedule.localVersion + 1;

    await _database.transaction(() async {
      await _dao.updateScheduleStatus(
        id: schedule.id,
        status: nextStatus,
        updatedAt: nowUtc,
        localVersion: nextVersion,
        completedAt: completed ? nowUtc : null,
      );

      await _enqueueSync(
        entityId: schedule.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': schedule.id,
          ..._scheduleMetadataPayload(
            description: schedule.description,
            location: schedule.location,
            category: schedule.category,
            isAllDay: schedule.isAllDay,
          ),
          'status': nextStatus,
          'recurrence_rule': schedule.recurrenceRule,
          'completed_at': completed ? nowUtc.toIso8601String() : null,
          'local_version': nextVersion,
          'updated_at': nowUtc.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: schedule.id,
        action: completed ? 'completed' : 'reopened',
        title: schedule.title,
        summary:
            completed ? 'Completed a schedule item' : 'Reopened a schedule item',
        occurredAt: nowUtc,
        recurrenceRule: schedule.recurrenceRule,
        description: schedule.description,
        location: schedule.location,
        category: schedule.category,
        isAllDay: schedule.isAllDay,
      );
    });

    if (completed) {
      await _reminderScheduler.cancelScheduleReminder(schedule.id);
    } else {
      await _reminderScheduler.syncScheduleReminder(
        schedule.copyWith(
          status: nextStatus,
          completedAt: Value<DateTime?>(completed ? nowUtc : null),
          updatedAt: nowUtc,
          localVersion: nextVersion,
        ),
      );
    }
  }

  Future<void> updateSchedule({
    required SchedulesTableData schedule,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required ScheduleReminderOption reminder,
    required ScheduleRecurrenceRule recurrence,
    String? description,
    String? location,
    String? category,
    bool? isAllDay,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final nextVersion = schedule.localVersion + 1;
    final normalizedTitle = title.trim();
    final recurrenceRule = ScheduleRecurrenceRule.normalizeRule(recurrence.rule);
    final nextDescription =
        description == null ? schedule.description : _normalizeOptionalText(description);
    final nextLocation =
        location == null ? schedule.location : _normalizeOptionalText(location);
    final nextCategory =
        category == null ? schedule.category : _normalizeOptionalText(category);
    final nextIsAllDay = isAllDay ?? schedule.isAllDay;

    await _database.transaction(() async {
      await _dao.updateSchedule(
        id: schedule.id,
        title: normalizedTitle,
        description: nextDescription,
        startAt: startAt,
        endAt: endAt,
        isAllDay: nextIsAllDay,
        location: nextLocation,
        category: nextCategory,
        recurrenceRule: recurrenceRule,
        reminderMinutesBefore: reminder.minutes,
        updatedAt: nowUtc,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityId: schedule.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': schedule.id,
          'title': normalizedTitle,
          ..._scheduleMetadataPayload(
            description: nextDescription,
            location: nextLocation,
            category: nextCategory,
            isAllDay: nextIsAllDay,
          ),
          'start_at': startAt.toIso8601String(),
          'end_at': endAt.toIso8601String(),
          'recurrence_rule': recurrenceRule,
          'reminder_minutes_before': reminder.minutes,
          'local_version': nextVersion,
          'updated_at': nowUtc.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: schedule.id,
        action: 'updated',
        title: normalizedTitle,
        summary: 'Updated a schedule item',
        occurredAt: nowUtc,
        recurrenceRule: recurrenceRule,
        description: nextDescription,
        location: nextLocation,
        category: nextCategory,
        isAllDay: nextIsAllDay,
      );
    });

    await _reminderScheduler.syncScheduleReminder(
      schedule.copyWith(
        title: normalizedTitle,
        description: Value(nextDescription),
        startAt: startAt,
        endAt: endAt,
        isAllDay: nextIsAllDay,
        location: Value(nextLocation),
        category: Value(nextCategory),
        recurrenceRule: Value(recurrenceRule),
        reminderMinutesBefore: Value<int?>(reminder.minutes),
        updatedAt: nowUtc,
        localVersion: nextVersion,
      ),
    );
  }

  Future<void> cancelSchedule(SchedulesTableData schedule) async {
    final nowUtc = DateTime.now().toUtc();
    final nextVersion = schedule.localVersion + 1;

    await _database.transaction(() async {
      await _dao.updateScheduleStatus(
        id: schedule.id,
        status: 'cancelled',
        updatedAt: nowUtc,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityId: schedule.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': schedule.id,
          ..._scheduleMetadataPayload(
            description: schedule.description,
            location: schedule.location,
            category: schedule.category,
            isAllDay: schedule.isAllDay,
          ),
          'status': 'cancelled',
          'recurrence_rule': schedule.recurrenceRule,
          'local_version': nextVersion,
          'updated_at': nowUtc.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: schedule.id,
        action: 'cancelled',
        title: schedule.title,
        summary: 'Cancelled a schedule item',
        occurredAt: nowUtc,
        recurrenceRule: schedule.recurrenceRule,
        description: schedule.description,
        location: schedule.location,
        category: schedule.category,
        isAllDay: schedule.isAllDay,
      );
    });

    await _reminderScheduler.cancelScheduleReminder(schedule.id);
  }

  Future<void> deleteSchedule(SchedulesTableData schedule) async {
    final nowUtc = DateTime.now().toUtc();
    final nextVersion = schedule.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.schedulesTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(schedule.id) &
                  tbl.userId.equals(_workspace.userId),
            ))
          .write(
        SchedulesTableCompanion(
          deletedAt: Value(nowUtc),
          updatedAt: Value(nowUtc),
          syncStatus: const Value('pending_delete'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: schedule.id,
        operation: 'delete',
        payload: <String, Object?>{
          'id': schedule.id,
          ..._scheduleMetadataPayload(
            description: schedule.description,
            location: schedule.location,
            category: schedule.category,
            isAllDay: schedule.isAllDay,
          ),
          'deleted_at': nowUtc.toIso8601String(),
          'recurrence_rule': schedule.recurrenceRule,
          'local_version': nextVersion,
          'updated_at': nowUtc.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: schedule.id,
        action: 'deleted',
        title: schedule.title,
        summary: 'Deleted a schedule item',
        occurredAt: nowUtc,
        recurrenceRule: schedule.recurrenceRule,
        description: schedule.description,
        location: schedule.location,
        category: schedule.category,
        isAllDay: schedule.isAllDay,
      );
    });

    await _reminderScheduler.cancelScheduleReminder(schedule.id);
  }

  Future<void> recordScheduleConvertedToTodo({
    required SchedulesTableData schedule,
    required String todoId,
  }) async {
    final current = await _resolveScheduleForMutation(schedule);
    final nowUtc = DateTime.now().toUtc();
    final nextVersion = current.localVersion + 1;
    final refreshed = current.copyWith(
      updatedAt: nowUtc,
      localVersion: nextVersion,
      syncStatus: _resolvePendingUpdateSyncStatus(current.syncStatus),
      deviceId: _workspace.deviceId,
    );

    await _database.transaction(() async {
      await (_database.update(_database.schedulesTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(current.id) &
                  tbl.userId.equals(_workspace.userId),
            ))
          .write(
        SchedulesTableCompanion(
          updatedAt: Value(nowUtc),
          syncStatus: Value(_resolvePendingUpdateSyncStatus(current.syncStatus)),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: current.id,
        operation: 'update',
        payload: <String, Object?>{
          ..._scheduleSyncPayload(refreshed),
          'action': 'converted_to_todo',
          'target_todo_id': todoId,
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: current.id,
        action: 'converted_to_todo',
        title: current.title,
        summary: 'Converted schedule to todo',
        occurredAt: nowUtc,
        recurrenceRule: current.recurrenceRule,
        description: current.description,
        location: current.location,
        category: current.category,
        isAllDay: current.isAllDay,
        extraPayload: <String, Object?>{
          'target_todo_id': todoId,
        },
      );
    });
  }

  Future<void> recordScheduleSyncedToHabitRecord({
    required SchedulesTableData schedule,
    required String habitId,
    required String habitRecordId,
    required DateTime recordDate,
    required String recordStatus,
  }) async {
    final current = await _resolveScheduleForMutation(schedule);
    final nowUtc = DateTime.now().toUtc();
    final nextVersion = current.localVersion + 1;
    final refreshed = current.copyWith(
      updatedAt: nowUtc,
      localVersion: nextVersion,
      syncStatus: _resolvePendingUpdateSyncStatus(current.syncStatus),
      deviceId: _workspace.deviceId,
    );

    await _database.transaction(() async {
      await (_database.update(_database.schedulesTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(current.id) &
                  tbl.userId.equals(_workspace.userId),
            ))
          .write(
        SchedulesTableCompanion(
          updatedAt: Value(nowUtc),
          syncStatus: Value(_resolvePendingUpdateSyncStatus(current.syncStatus)),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: current.id,
        operation: 'update',
        payload: <String, Object?>{
          ..._scheduleSyncPayload(refreshed),
          'action': 'synced_habit_record',
          'target_habit_id': habitId,
          'target_habit_record_id': habitRecordId,
          'record_date': recordDate.toUtc().toIso8601String(),
          'record_status': recordStatus,
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: current.id,
        action: 'synced_habit_record',
        title: current.title,
        summary: 'Synced schedule to habit record',
        occurredAt: nowUtc,
        recurrenceRule: current.recurrenceRule,
        description: current.description,
        location: current.location,
        category: current.category,
        isAllDay: current.isAllDay,
        extraPayload: <String, Object?>{
          'target_habit_id': habitId,
          'target_habit_record_id': habitRecordId,
          'record_date': recordDate.toUtc().toIso8601String(),
          'record_status': recordStatus,
        },
      );
    });
  }

  Future<SchedulesTableData> postponeScheduleByDays({
    required SchedulesTableData schedule,
    int days = 1,
  }) async {
    final current = await _resolveScheduleForMutation(schedule);
    if (days == 0) {
      return current;
    }

    final nowUtc = DateTime.now().toUtc();
    final nextVersion = current.localVersion + 1;
    final shiftedStartAt = current.startAt.add(Duration(days: days));
    final shiftedEndAt = current.endAt.add(Duration(days: days));

    await _database.transaction(() async {
      await _dao.updateSchedule(
        id: current.id,
        title: current.title,
        description: current.description,
        startAt: shiftedStartAt,
        endAt: shiftedEndAt,
        isAllDay: current.isAllDay,
        location: current.location,
        category: current.category,
        recurrenceRule: current.recurrenceRule,
        reminderMinutesBefore: current.reminderMinutesBefore,
        updatedAt: nowUtc,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityId: current.id,
        operation: 'update',
        payload: <String, Object?>{
          ..._scheduleSyncPayload(
            current.copyWith(
              startAt: shiftedStartAt,
              endAt: shiftedEndAt,
              updatedAt: nowUtc,
              localVersion: nextVersion,
            ),
          ),
          'action': 'postponed',
          'postpone_days': days,
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: current.id,
        action: 'postponed',
        title: current.title,
        summary: 'Postponed a schedule item',
        occurredAt: nowUtc,
        recurrenceRule: current.recurrenceRule,
        description: current.description,
        location: current.location,
        category: current.category,
        isAllDay: current.isAllDay,
        extraPayload: <String, Object?>{
          'postpone_days': days,
          'start_at': shiftedStartAt.toIso8601String(),
          'end_at': shiftedEndAt.toIso8601String(),
        },
      );
    });

    final updatedSchedule = current.copyWith(
      startAt: shiftedStartAt,
      endAt: shiftedEndAt,
      updatedAt: nowUtc,
      localVersion: nextVersion,
      syncStatus: 'pending_update',
      deviceId: _workspace.deviceId,
    );
    await _reminderScheduler.syncScheduleReminder(updatedSchedule);
    return updatedSchedule;
  }

  Future<void> _enqueueSync({
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    return _database.into(_database.syncQueueTable).insert(
          SyncQueueTableCompanion.insert(
            id: _uuid.v4(),
            userId: Value(_workspace.userId),
            entityType: 'schedule',
            entityId: entityId,
            operation: operation,
            payloadJson: jsonEncode(payload),
          ),
        );
  }

  Future<void> _appendTimelineEvent({
    required String sourceEntityId,
    required String action,
    required String title,
    required String summary,
    required DateTime occurredAt,
    String? recurrenceRule,
    String? description,
    String? location,
    String? category,
    bool? isAllDay,
    Map<String, Object?>? extraPayload,
  }) {
    return _database.into(_database.timelineEventsTable).insert(
          TimelineEventsTableCompanion.insert(
            id: _uuid.v4(),
            userId: _workspace.userId,
            eventType: 'schedule',
            eventAction: action,
            sourceEntityId: sourceEntityId,
            sourceEntityType: 'schedule',
            occurredAt: occurredAt,
            title: title,
            summary: Value(summary),
            payloadJson: Value(
              jsonEncode(
                <String, Object?>{
                  'action': action,
                  'title': title,
                  ..._scheduleMetadataPayload(
                    description: description,
                    location: location,
                    category: category,
                    isAllDay: isAllDay,
                  ),
                  'recurrence_rule': recurrenceRule,
                  ...?extraPayload,
                },
              ),
            ),
            createdAt: Value(occurredAt),
            updatedAt: Value(occurredAt),
            syncStatus: const Value('pending_create'),
            localVersion: const Value(1),
            deviceId: Value(_workspace.deviceId),
          ),
        );
  }

  Map<String, Object?> _scheduleMetadataPayload({
    String? description,
    String? location,
    String? category,
    bool? isAllDay,
  }) {
    return <String, Object?>{
      'description': description,
      'location': location,
      'category': category,
      'is_all_day': isAllDay,
    };
  }

  String? _normalizeOptionalText(String? input) {
    final normalized = input?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Map<String, Object?> _scheduleSyncPayload(SchedulesTableData schedule) {
    return <String, Object?>{
      'id': schedule.id,
      'title': schedule.title,
      ..._scheduleMetadataPayload(
        description: schedule.description,
        location: schedule.location,
        category: schedule.category,
        isAllDay: schedule.isAllDay,
      ),
      'start_at': schedule.startAt.toIso8601String(),
      'end_at': schedule.endAt.toIso8601String(),
      'status': schedule.status,
      'recurrence_rule': schedule.recurrenceRule,
      'reminder_minutes_before': schedule.reminderMinutesBefore,
      'source_todo_id': schedule.sourceTodoId,
      'local_version': schedule.localVersion,
      'updated_at': schedule.updatedAt.toIso8601String(),
    };
  }

  String _resolvePendingUpdateSyncStatus(String currentStatus) {
    if (currentStatus == 'pending_create') {
      return 'pending_create';
    }
    return 'pending_update';
  }

  Future<SchedulesTableData> _resolveScheduleForMutation(
    SchedulesTableData fallback,
  ) async {
    final current = await (_database.select(_database.schedulesTable)
          ..where(
            (tbl) =>
                tbl.id.equals(fallback.id) &
                tbl.userId.equals(_workspace.userId) &
                tbl.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    return current ?? fallback;
  }
}
