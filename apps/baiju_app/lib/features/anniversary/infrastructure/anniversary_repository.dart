import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class AnniversaryRepository {
  AnniversaryRepository(this._database, {UserWorkspace? workspace, Uuid? uuid})
    : _workspace = workspace ?? const UserWorkspace.local(),
      _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final UserWorkspace _workspace;
  final Uuid _uuid;

  Stream<List<AnniversariesTableData>> watchAnniversaries() {
    final query = _database.select(_database.anniversariesTable)
      ..where(
        (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
      )
      ..orderBy(<OrderingTerm Function($AnniversariesTableTable)>[
        (tbl) => OrderingTerm.asc(tbl.baseDate),
        (tbl) => OrderingTerm.desc(tbl.updatedAt),
      ]);

    return query.watch();
  }

  Future<void> createAnniversary({
    required String title,
    required DateTime baseDate,
    required AnniversaryReminderOption reminder,
    String? category,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final anniversaryId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.anniversariesTable)
          .insert(
            AnniversariesTableCompanion.insert(
              id: anniversaryId,
              userId: _workspace.userId,
              title: title.trim(),
              baseDate: _toUtcDate(baseDate),
              remindDaysBefore: Value(reminder.days),
              category: Value(_emptyToNull(category)),
              note: Value(_emptyToNull(note)),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncStatus: const Value('pending_create'),
              localVersion: const Value(1),
              deviceId: Value(_workspace.deviceId),
            ),
          );

      await _enqueueSync(
        entityId: anniversaryId,
        operation: 'create',
        payload: <String, Object?>{
          'id': anniversaryId,
          'title': title.trim(),
          'base_date': _toUtcDate(baseDate).toIso8601String(),
          'calendar_type': 'solar',
          'remind_days_before': reminder.days,
          'category': _emptyToNull(category),
          'note': _emptyToNull(note),
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: anniversaryId,
        action: 'created',
        title: title.trim(),
        summary: '新增了一个纪念日',
        occurredAt: now,
      );
    });
  }

  Future<void> updateAnniversary({
    required AnniversariesTableData anniversary,
    required String title,
    required DateTime baseDate,
    required AnniversaryReminderOption reminder,
    String? category,
    String? note,
  }) async {
    final now = DateTime.now().toUtc();
    final nextVersion = anniversary.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.anniversariesTable)..where(
            (tbl) =>
                tbl.id.equals(anniversary.id) &
                tbl.userId.equals(_workspace.userId),
          ))
          .write(
            AnniversariesTableCompanion(
              title: Value(title.trim()),
              baseDate: Value(_toUtcDate(baseDate)),
              remindDaysBefore: Value(reminder.days),
              category: Value(_emptyToNull(category)),
              note: Value(_emptyToNull(note)),
              updatedAt: Value(now),
              syncStatus: const Value('pending_update'),
              localVersion: Value(nextVersion),
              deviceId: Value(_workspace.deviceId),
            ),
          );

      await _enqueueSync(
        entityId: anniversary.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': anniversary.id,
          'title': title.trim(),
          'base_date': _toUtcDate(baseDate).toIso8601String(),
          'remind_days_before': reminder.days,
          'category': _emptyToNull(category),
          'note': _emptyToNull(note),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: anniversary.id,
        action: 'updated',
        title: title.trim(),
        summary: '更新了一个纪念日',
        occurredAt: now,
      );
    });
  }

  Future<void> deleteAnniversary(AnniversariesTableData anniversary) async {
    final now = DateTime.now().toUtc();
    final nextVersion = anniversary.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.anniversariesTable)..where(
            (tbl) =>
                tbl.id.equals(anniversary.id) &
                tbl.userId.equals(_workspace.userId),
          ))
          .write(
            AnniversariesTableCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              syncStatus: const Value('pending_delete'),
              localVersion: Value(nextVersion),
              deviceId: Value(_workspace.deviceId),
            ),
          );

      await _enqueueSync(
        entityId: anniversary.id,
        operation: 'delete',
        payload: <String, Object?>{
          'id': anniversary.id,
          'deleted_at': now.toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: anniversary.id,
        action: 'deleted',
        title: anniversary.title,
        summary: '删除了一个纪念日',
        occurredAt: now,
      );
    });
  }

  Future<void> _enqueueSync({
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    return _database
        .into(_database.syncQueueTable)
        .insert(
          SyncQueueTableCompanion.insert(
            id: _uuid.v4(),
            userId: Value(_workspace.userId),
            entityType: 'anniversary',
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
  }) {
    return _database
        .into(_database.timelineEventsTable)
        .insert(
          TimelineEventsTableCompanion.insert(
            id: _uuid.v4(),
            userId: _workspace.userId,
            eventType: 'anniversary',
            eventAction: action,
            sourceEntityId: sourceEntityId,
            sourceEntityType: 'anniversary',
            occurredAt: occurredAt,
            title: title,
            summary: Value(summary),
            payloadJson: Value(
              jsonEncode(<String, Object?>{'action': action, 'title': title}),
            ),
            createdAt: Value(occurredAt),
            updatedAt: Value(occurredAt),
            syncStatus: const Value('pending_create'),
            localVersion: const Value(1),
            deviceId: Value(_workspace.deviceId),
          ),
        );
  }

  DateTime _toUtcDate(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    return local.toUtc();
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
