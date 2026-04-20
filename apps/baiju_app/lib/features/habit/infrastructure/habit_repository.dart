import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/habit_dao.dart';
import 'package:baiju_app/core/notifications/reminder_scheduler.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class HabitRepository {
  HabitRepository(
    this._database,
    this._dao, {
    ReminderScheduler? reminderScheduler,
    UserWorkspace? workspace,
    Uuid? uuid,
  })  : _reminderScheduler = reminderScheduler ?? const NoopReminderScheduler(),
        _workspace = workspace ?? const UserWorkspace.local(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final HabitDao _dao;
  final ReminderScheduler _reminderScheduler;
  final UserWorkspace _workspace;
  final Uuid _uuid;

  Stream<List<HabitTodayItem>> watchHabitsForToday() {
    return _dao.watchHabitsForToday();
  }

  Stream<HabitDetailInsights> watchHabitDetailInsights(
    String habitId, {
    int recentDays = 14,
  }) {
    return (_database.select(_database.habitRecordsTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_workspace.userId) &
                tbl.habitId.equals(habitId),
          )
          ..orderBy([
            (tbl) => OrderingTerm.desc(tbl.recordDate),
            (tbl) => OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch()
        .map((records) {
      final statusByDay = _buildStatusByDay(records);
      final today = _todayStartUtc();

      return HabitDetailInsights(
        stats7Days: _buildCompletionStats(
          window: HabitStatsWindow.last7Days,
          statusByDay: statusByDay,
          today: today,
        ),
        stats30Days: _buildCompletionStats(
          window: HabitStatsWindow.last30Days,
          statusByDay: statusByDay,
          today: today,
        ),
        recentRecords: _buildRecentStates(
          statusByDay: statusByDay,
          today: today,
          days: recentDays,
        ),
      );
    });
  }

  Future<void> createHabit({
    required String name,
    required String? reminderTime,
    String? goalId,
    double progressWeight = 1.0,
  }) async {
    final now = DateTime.now().toUtc();
    final habitId = _uuid.v4();
    final trimmedName = name.trim();

    final companion = HabitsTableCompanion.insert(
      id: habitId,
      userId: _workspace.userId,
      name: trimmedName,
      frequencyType: const Value('daily'),
      frequencyRule: 'daily',
      reminderTime: Value(reminderTime),
      goalId: Value(goalId),
      progressWeight: Value(progressWeight),
      startDate: now,
      status: const Value('active'),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending_create'),
      localVersion: const Value(1),
      deviceId: Value(_workspace.deviceId),
    );

    final habit = HabitsTableData(
      id: habitId,
      userId: _workspace.userId,
      name: trimmedName,
      description: null,
      frequencyType: 'daily',
      frequencyRule: 'daily',
      reminderTime: reminderTime,
      goalId: goalId,
      progressWeight: progressWeight,
      startDate: now,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'pending_create',
      localVersion: 1,
      remoteVersion: null,
      lastSyncedAt: null,
      deviceId: _workspace.deviceId,
    );

    await _database.transaction(() async {
      await _dao.insertHabit(companion);
      await _enqueueSync(
        entityType: 'habit',
        entityId: habitId,
        operation: 'create',
        payload: <String, Object?>{
          'id': habitId,
          'name': trimmedName,
          'reminder_time': reminderTime,
          'goal_id': goalId,
          'progress_weight': progressWeight,
          'status': 'active',
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        eventType: 'habit',
        sourceEntityId: habitId,
        action: 'created',
        title: trimmedName,
        summary: '新增了一个习惯',
        occurredAt: now,
      );
    });

    await _reminderScheduler.syncHabitReminder(habit);
  }

  Future<void> toggleHabitCheckIn(HabitTodayItem item, bool checked) async {
    final habit = item.habit;
    if (habit.status == 'paused') {
      return;
    }

    final now = DateTime.now().toUtc();
    final todayStart = _todayStartUtc();
    final nextVersion = habit.localVersion + 1;
    final nextStatus =
        checked ? HabitRecordStatus.done : HabitRecordStatus.skipped;
    late final _HabitRecordMutation mutation;

    await _database.transaction(() async {
      mutation = await _upsertHabitRecord(
        habit: habit,
        recordDate: todayStart,
        status: nextStatus,
        now: now,
      );

      await _dao.updateHabitTimestamp(
        id: habit.id,
        updatedAt: now,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityType: 'habit_record',
        entityId: mutation.recordId,
        operation: mutation.operation,
        payload: <String, Object?>{
          'id': mutation.recordId,
          'habit_id': habit.id,
          'record_date': todayStart.toIso8601String(),
          'status': nextStatus.value,
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        eventType: 'habit',
        sourceEntityId: habit.id,
        action: checked ? 'checked_in' : 'unchecked',
        title: habit.name,
        summary: checked ? '完成了一次习惯打卡' : '标记了一次习惯跳过',
        occurredAt: now,
      );
    });
  }

  Future<void> backfillHabitRecord({
    required HabitsTableData habit,
    required DateTime recordDate,
    required HabitRecordStatus status,
  }) async {
    if (habit.status == 'paused' || status == HabitRecordStatus.none) {
      return;
    }

    final targetDate = _startOfDayUtc(recordDate);
    final today = _todayStartUtc();
    if (targetDate.isAfter(today)) {
      throw ArgumentError.value(recordDate, 'recordDate', '不能补记未来日期');
    }

    final now = DateTime.now().toUtc();
    final nextVersion = habit.localVersion + 1;
    late final _HabitRecordMutation mutation;

    await _database.transaction(() async {
      mutation = await _upsertHabitRecord(
        habit: habit,
        recordDate: targetDate,
        status: status,
        now: now,
      );

      await _dao.updateHabitTimestamp(
        id: habit.id,
        updatedAt: now,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityType: 'habit_record',
        entityId: mutation.recordId,
        operation: mutation.operation,
        payload: <String, Object?>{
          'id': mutation.recordId,
          'habit_id': habit.id,
          'record_date': targetDate.toIso8601String(),
          'status': status.value,
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        eventType: 'habit',
        sourceEntityId: habit.id,
        action: 'backfilled',
        title: habit.name,
        summary: '补记了${_formatDate(targetDate)}的打卡：${status.label}',
        occurredAt: now,
      );
    });
  }

  Future<String?> syncHabitRecordFromSchedule({
    required HabitsTableData habit,
    required SchedulesTableData schedule,
    HabitRecordStatus status = HabitRecordStatus.done,
    DateTime? recordDate,
  }) async {
    if (habit.status == 'paused' || status == HabitRecordStatus.none) {
      return null;
    }

    final targetDate = _startOfDayUtc(recordDate ?? schedule.startAt);
    final today = _todayStartUtc();
    if (targetDate.isAfter(today)) {
      throw ArgumentError.value(
        recordDate ?? schedule.startAt,
        'recordDate',
        'cannot sync a future record',
      );
    }

    final now = DateTime.now().toUtc();
    final nextVersion = habit.localVersion + 1;
    late final _HabitRecordMutation mutation;

    await _database.transaction(() async {
      mutation = await _upsertHabitRecord(
        habit: habit,
        recordDate: targetDate,
        status: status,
        now: now,
        sourceScheduleId: schedule.id,
      );

      await _dao.updateHabitTimestamp(
        id: habit.id,
        updatedAt: now,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityType: 'habit_record',
        entityId: mutation.recordId,
        operation: mutation.operation,
        payload: <String, Object?>{
          'id': mutation.recordId,
          'habit_id': habit.id,
          'record_date': targetDate.toIso8601String(),
          'status': status.value,
          'source_schedule_id': schedule.id,
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        eventType: 'habit',
        sourceEntityId: habit.id,
        action: 'synced_from_schedule',
        title: habit.name,
        summary: 'Synced habit record from schedule',
        occurredAt: now,
        payload: <String, Object?>{
          'source_schedule_id': schedule.id,
          'habit_record_id': mutation.recordId,
          'record_date': targetDate.toIso8601String(),
          'record_status': status.value,
        },
      );
    });

    return mutation.recordId;
  }

  Future<void> updateHabit({
    required HabitsTableData habit,
    required String name,
    required String? reminderTime,
    String? goalId,
    double? progressWeight,
  }) async {
    final now = DateTime.now().toUtc();
    final nextVersion = habit.localVersion + 1;
    final nextWeight = progressWeight ?? habit.progressWeight;
    final trimmedName = name.trim();

    await _database.transaction(() async {
      await _dao.updateHabit(
        id: habit.id,
        name: trimmedName,
        reminderTime: reminderTime,
        goalId: goalId,
        progressWeight: nextWeight,
        updatedAt: now,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityType: 'habit',
        entityId: habit.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': habit.id,
          'name': trimmedName,
          'reminder_time': reminderTime,
          'goal_id': goalId,
          'progress_weight': nextWeight,
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        eventType: 'habit',
        sourceEntityId: habit.id,
        action: 'updated',
        title: trimmedName,
        summary: '更新了一个习惯',
        occurredAt: now,
      );
    });

    await _reminderScheduler.syncHabitReminder(
      habit.copyWith(
        name: trimmedName,
        reminderTime: Value<String?>(reminderTime),
        goalId: Value<String?>(goalId),
        progressWeight: nextWeight,
        updatedAt: now,
        localVersion: nextVersion,
      ),
    );
  }

  Future<void> setHabitPaused(HabitsTableData habit, bool paused) async {
    final now = DateTime.now().toUtc();
    final nextVersion = habit.localVersion + 1;
    final nextStatus = paused ? 'paused' : 'active';

    await _database.transaction(() async {
      await (_database.update(_database.habitsTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(habit.id) &
                  tbl.userId.equals(_workspace.userId),
            ))
          .write(
        HabitsTableCompanion(
          status: Value(nextStatus),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityType: 'habit',
        entityId: habit.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': habit.id,
          'status': nextStatus,
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        eventType: 'habit',
        sourceEntityId: habit.id,
        action: paused ? 'paused' : 'resumed',
        title: habit.name,
        summary: paused ? '暂停了一个习惯' : '恢复了一个习惯',
        occurredAt: now,
      );
    });

    if (paused) {
      await _reminderScheduler.cancelHabitReminder(habit.id);
      return;
    }

    await _reminderScheduler.syncHabitReminder(
      habit.copyWith(
        status: nextStatus,
        updatedAt: now,
        localVersion: nextVersion,
      ),
    );
  }

  Future<void> deleteHabit(HabitsTableData habit) async {
    final now = DateTime.now().toUtc();
    final nextVersion = habit.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.habitsTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(habit.id) &
                  tbl.userId.equals(_workspace.userId),
            ))
          .write(
        HabitsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending_delete'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityType: 'habit',
        entityId: habit.id,
        operation: 'delete',
        payload: <String, Object?>{
          'id': habit.id,
          'deleted_at': now.toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        eventType: 'habit',
        sourceEntityId: habit.id,
        action: 'deleted',
        title: habit.name,
        summary: '删除了一个习惯',
        occurredAt: now,
      );
    });

    await _reminderScheduler.cancelHabitReminder(habit.id);
  }

  Future<void> _enqueueSync({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    return _database.into(_database.syncQueueTable).insert(
          SyncQueueTableCompanion.insert(
            id: _uuid.v4(),
            userId: Value(_workspace.userId),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payloadJson: jsonEncode(payload),
          ),
        );
  }

  Future<void> _appendTimelineEvent({
    required String eventType,
    required String sourceEntityId,
    required String action,
    required String title,
    required String summary,
    required DateTime occurredAt,
    Map<String, Object?>? payload,
  }) {
    return _database.into(_database.timelineEventsTable).insert(
          TimelineEventsTableCompanion.insert(
            id: _uuid.v4(),
            userId: _workspace.userId,
            eventType: eventType,
            eventAction: action,
            sourceEntityId: sourceEntityId,
            sourceEntityType: eventType,
            occurredAt: occurredAt,
            title: title,
            summary: Value(summary),
            payloadJson: Value(
              jsonEncode(
                <String, Object?>{
                  'action': action,
                  'title': title,
                  ...?payload,
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

  HabitCompletionStats _buildCompletionStats({
    required HabitStatsWindow window,
    required Map<DateTime, HabitRecordStatus> statusByDay,
    required DateTime today,
  }) {
    final start = today.subtract(Duration(days: window.days - 1));
    var doneDays = 0;
    var skippedDays = 0;

    for (var offset = 0; offset < window.days; offset++) {
      final day = today.subtract(Duration(days: offset));
      final status = statusByDay[day] ?? HabitRecordStatus.none;
      if (status == HabitRecordStatus.done) {
        doneDays++;
      } else if (status == HabitRecordStatus.skipped) {
        skippedDays++;
      }
    }

    return HabitCompletionStats(
      window: window,
      totalDays: window.days,
      doneDays: doneDays,
      skippedDays: skippedDays,
      missingDays: window.days - doneDays - skippedDays,
      currentStreak: _calculateCurrentStreak(
        statusByDay: statusByDay,
        today: today,
      ),
      longestStreak: _calculateLongestStreak(
        statusByDay: statusByDay,
        start: start,
        end: today,
      ),
    );
  }

  int _calculateCurrentStreak({
    required Map<DateTime, HabitRecordStatus> statusByDay,
    required DateTime today,
  }) {
    var streak = 0;
    var cursor = today;
    while ((statusByDay[cursor] ?? HabitRecordStatus.none) ==
        HabitRecordStatus.done) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _calculateLongestStreak({
    required Map<DateTime, HabitRecordStatus> statusByDay,
    required DateTime start,
    required DateTime end,
  }) {
    var cursor = start;
    var current = 0;
    var longest = 0;

    while (!cursor.isAfter(end)) {
      if ((statusByDay[cursor] ?? HabitRecordStatus.none) ==
          HabitRecordStatus.done) {
        current++;
        if (current > longest) {
          longest = current;
        }
      } else {
        current = 0;
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return longest;
  }

  List<HabitRecordDayState> _buildRecentStates({
    required Map<DateTime, HabitRecordStatus> statusByDay,
    required DateTime today,
    required int days,
  }) {
    return List<HabitRecordDayState>.generate(days, (index) {
      final day = today.subtract(Duration(days: index));
      return HabitRecordDayState(
        date: day,
        status: statusByDay[day] ?? HabitRecordStatus.none,
      );
    });
  }

  Map<DateTime, HabitRecordStatus> _buildStatusByDay(
    List<HabitRecordsTableData> records,
  ) {
    final latestRecordByDay = <DateTime, HabitRecordsTableData>{};
    for (final record in records) {
      final day = _startOfDayUtc(record.recordDate);
      final existing = latestRecordByDay[day];
      if (existing == null || record.updatedAt.isAfter(existing.updatedAt)) {
        latestRecordByDay[day] = record;
      }
    }

    return <DateTime, HabitRecordStatus>{
      for (final entry in latestRecordByDay.entries)
        entry.key: HabitRecordStatus.fromValue(entry.value.status),
    };
  }

  Future<_HabitRecordMutation> _upsertHabitRecord({
    required HabitsTableData habit,
    required DateTime recordDate,
    required HabitRecordStatus status,
    required DateTime now,
    String? sourceScheduleId,
  }) async {
    final recordDay = _startOfDayUtc(recordDate);
    final recordDayEnd = recordDay.add(const Duration(days: 1));

    final currentRecord = await (_database.select(_database.habitRecordsTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_workspace.userId) &
                tbl.habitId.equals(habit.id) &
                tbl.recordDate.isBiggerOrEqualValue(recordDay) &
                tbl.recordDate.isSmallerThanValue(recordDayEnd),
          ))
        .getSingleOrNull();

    if (currentRecord == null) {
      final newRecordId = _uuid.v4();
      await _dao.insertHabitRecord(
        HabitRecordsTableCompanion.insert(
          id: newRecordId,
          habitId: habit.id,
          userId: _workspace.userId,
          recordDate: recordDay,
          recordedAt: now,
          status: Value(status.value),
          sourceScheduleId: Value(sourceScheduleId),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending_create'),
          localVersion: const Value(1),
          deviceId: Value(_workspace.deviceId),
        ),
      );
      return _HabitRecordMutation(operation: 'create', recordId: newRecordId);
    }

    if (sourceScheduleId == null) {
      await _dao.updateHabitRecord(
        id: currentRecord.id,
        status: status.value,
        recordedAt: now,
        updatedAt: now,
        localVersion: currentRecord.localVersion + 1,
      );
    } else {
      await (_database.update(_database.habitRecordsTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(currentRecord.id) &
                  tbl.userId.equals(_workspace.userId),
            ))
          .write(
        HabitRecordsTableCompanion(
          status: Value(status.value),
          recordedAt: Value(now),
          sourceScheduleId: Value(sourceScheduleId),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(currentRecord.localVersion + 1),
          deviceId: Value(_workspace.deviceId),
        ),
      );
    }
    return _HabitRecordMutation(
      operation: 'update',
      recordId: currentRecord.id,
    );
  }

  DateTime _todayStartUtc() => _startOfDayUtc(DateTime.now());

  DateTime _startOfDayUtc(DateTime source) {
    return DateTime.utc(source.year, source.month, source.day);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _HabitRecordMutation {
  const _HabitRecordMutation({
    required this.operation,
    required this.recordId,
  });

  final String operation;
  final String recordId;
}
