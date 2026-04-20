import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.failed,
    this.error,
  });

  const SyncResult.empty()
      : pushed = 0,
        pulled = 0,
        failed = 0,
        error = null;

  const SyncResult.notConfigured()
      : pushed = 0,
        pulled = 0,
        failed = 0,
        error = 'Supabase not configured';

  final int pushed;
  final int pulled;
  final int failed;
  final String? error;

  bool get hasError => error != null;
  bool get isSuccess => !hasError;
}

/// Processes the local sync_queue and syncs with Supabase.
///
/// When Supabase is not configured (empty URL/key), all operations are no-ops
/// and the queue is left untouched.
class SyncEngine {
  SyncEngine(this._database, this._userId);

  final AppDatabase _database;
  final String _userId;

  bool get isConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get _client {
    if (!isConfigured) return null;
    return Supabase.instance.client;
  }

  /// Push all pending local changes to Supabase.
  Future<SyncResult> pushPendingChanges() async {
    final client = _client;
    if (client == null) return const SyncResult.notConfigured();

    final pending = await (_database.select(_database.syncQueueTable)
          ..where(
            (tbl) =>
                tbl.userId.equals(_userId) &
                tbl.status.isNotValue('done') &
                tbl.status.isNotValue('failed'),
          )
          ..orderBy(<OrderingTerm Function($SyncQueueTableTable)>[
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .get();

    if (pending.isEmpty) return const SyncResult.empty();

    var pushed = 0;
    var failed = 0;

    for (final item in pending) {
      try {
        await _processQueueItem(client, item);
        await _markDone(item.id);
        pushed++;
      } catch (e) {
        await _markFailed(item, e.toString());
        failed++;
      }
    }

    return SyncResult(pushed: pushed, pulled: 0, failed: failed);
  }

  /// Pull remote changes from Supabase for all entity types.
  Future<SyncResult> pullRemoteChanges() async {
    final client = _client;
    if (client == null) return const SyncResult.notConfigured();

    var pulled = 0;
    var failed = 0;

    for (final entityType in _entityTypes) {
      try {
        final count = await _pullEntityType(client, entityType);
        pulled += count;
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(pushed: 0, pulled: pulled, failed: failed);
  }

  /// Full sync: push local changes then pull remote changes.
  Future<SyncResult> sync() async {
    final pushResult = await pushPendingChanges();
    if (pushResult.error == 'Supabase not configured') {
      return const SyncResult.notConfigured();
    }

    final pullResult = await pullRemoteChanges();

    return SyncResult(
      pushed: pushResult.pushed,
      pulled: pullResult.pulled,
      failed: pushResult.failed + pullResult.failed,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static const List<String> _entityTypes = <String>[
    'todo',
    'schedule',
    'habit',
    'anniversary',
    'goal',
    'note',
  ];

  Future<void> _processQueueItem(
    SupabaseClient client,
    SyncQueueTableData item,
  ) async {
    final payload = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final table = _tableNameFor(item.entityType);

    switch (item.operation) {
      case 'create':
      case 'update':
        await client.from(table).upsert(<String, dynamic>{
          ...payload,
          'user_id': _userId,
        });
      case 'delete':
        await client
            .from(table)
            .update(<String, dynamic>{
              'deleted_at': payload['deleted_at'],
              'updated_at': payload['updated_at'],
            })
            .eq('id', item.entityId)
            .eq('user_id', _userId);
    }
  }

  Future<int> _pullEntityType(SupabaseClient client, String entityType) async {
    final table = _tableNameFor(entityType);
    final lastSync = await _lastPulledAt(entityType);

    final query = client.from(table).select().eq('user_id', _userId);

    final rows = lastSync != null
        ? await query.gt('updated_at', lastSync.toIso8601String())
        : await query;

    if (rows.isEmpty) return 0;

    await _upsertLocalRows(entityType, rows);
    await _updateLastPulledAt(entityType);

    return rows.length;
  }

  Future<void> _upsertLocalRows(
    String entityType,
    List<Map<String, dynamic>> rows,
  ) async {
    final now = DateTime.now().toUtc();

    switch (entityType) {
      case 'todo':
        for (final row in rows) {
          await _database
              .into(_database.todosTable)
              .insertOnConflictUpdate(_todoFromRemote(row, now));
        }
      case 'schedule':
        for (final row in rows) {
          await _database
              .into(_database.schedulesTable)
              .insertOnConflictUpdate(_scheduleFromRemote(row, now));
        }
      case 'habit':
        for (final row in rows) {
          await _database
              .into(_database.habitsTable)
              .insertOnConflictUpdate(_habitFromRemote(row, now));
        }
      case 'anniversary':
        for (final row in rows) {
          await _database
              .into(_database.anniversariesTable)
              .insertOnConflictUpdate(_anniversaryFromRemote(row, now));
        }
      case 'goal':
        for (final row in rows) {
          await _database
              .into(_database.goalsTable)
              .insertOnConflictUpdate(_goalFromRemote(row, now));
        }
      case 'note':
        for (final row in rows) {
          await _database
              .into(_database.notesTable)
              .insertOnConflictUpdate(_noteFromRemote(row, now));
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Remote → local companion builders
  // ---------------------------------------------------------------------------

  TodosTableCompanion _todoFromRemote(
    Map<String, dynamic> row,
    DateTime syncedAt,
  ) {
    return TodosTableCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String? ?? _userId),
      title: Value(row['title'] as String),
      description: Value(row['description'] as String?),
      priority: Value(row['priority'] as String? ?? 'medium'),
      status: Value(row['status'] as String? ?? 'open'),
      dueAt: Value(_parseDateTime(row['due_at'])),
      plannedAt: Value(_parseDateTime(row['planned_at'])),
      completedAt: Value(_parseDateTime(row['completed_at'])),
      goalId: Value(row['goal_id'] as String?),
      convertedScheduleId: Value(row['converted_schedule_id'] as String?),
      deletedAt: Value(_parseDateTime(row['deleted_at'])),
      syncStatus: const Value('synced'),
      remoteVersion: Value(row['local_version'] as int? ?? 1),
      lastSyncedAt: Value(syncedAt),
      updatedAt: Value(_parseDateTime(row['updated_at']) ?? syncedAt),
      createdAt: Value(_parseDateTime(row['created_at']) ?? syncedAt),
    );
  }

  SchedulesTableCompanion _scheduleFromRemote(
    Map<String, dynamic> row,
    DateTime syncedAt,
  ) {
    return SchedulesTableCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String? ?? _userId),
      title: Value(row['title'] as String),
      description: Value(row['description'] as String?),
      location: Value(row['location'] as String?),
      category: Value(row['category'] as String?),
      startAt: Value(
        _parseDateTime(row['start_at']) ?? DateTime.now().toUtc(),
      ),
      endAt: Value(
        _parseDateTime(row['end_at']) ?? DateTime.now().toUtc(),
      ),
      isAllDay: Value(row['is_all_day'] as bool? ?? false),
      status: Value(row['status'] as String? ?? 'planned'),
      recurrenceRule: Value(row['recurrence_rule'] as String?),
      reminderMinutesBefore: Value(row['reminder_minutes_before'] as int?),
      sourceTodoId: Value(row['source_todo_id'] as String?),
      deletedAt: Value(_parseDateTime(row['deleted_at'])),
      syncStatus: const Value('synced'),
      remoteVersion: Value(row['local_version'] as int? ?? 1),
      lastSyncedAt: Value(syncedAt),
      updatedAt: Value(_parseDateTime(row['updated_at']) ?? syncedAt),
      createdAt: Value(_parseDateTime(row['created_at']) ?? syncedAt),
    );
  }

  HabitsTableCompanion _habitFromRemote(
    Map<String, dynamic> row,
    DateTime syncedAt,
  ) {
    return HabitsTableCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String? ?? _userId),
      name: Value(row['name'] as String),
      frequencyType: Value(row['frequency_type'] as String? ?? 'daily'),
      frequencyRule: Value(row['frequency_rule'] as String? ?? ''),
      reminderTime: Value(row['reminder_time'] as String?),
      status: Value(row['status'] as String? ?? 'active'),
      goalId: Value(row['goal_id'] as String?),
      progressWeight: Value(
        (row['progress_weight'] as num?)?.toDouble() ?? 1.0,
      ),
      startDate: Value(
        _parseDateTime(row['start_date']) ?? DateTime.now().toUtc(),
      ),
      deletedAt: Value(_parseDateTime(row['deleted_at'])),
      syncStatus: const Value('synced'),
      remoteVersion: Value(row['local_version'] as int? ?? 1),
      lastSyncedAt: Value(syncedAt),
      updatedAt: Value(_parseDateTime(row['updated_at']) ?? syncedAt),
      createdAt: Value(_parseDateTime(row['created_at']) ?? syncedAt),
    );
  }

  AnniversariesTableCompanion _anniversaryFromRemote(
    Map<String, dynamic> row,
    DateTime syncedAt,
  ) {
    return AnniversariesTableCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String? ?? _userId),
      title: Value(row['title'] as String),
      baseDate: Value(
        _parseDateTime(row['base_date']) ?? DateTime.now().toUtc(),
      ),
      category: Value(row['category'] as String?),
      note: Value(row['note'] as String?),
      remindDaysBefore: Value(row['remind_days_before'] as int?),
      deletedAt: Value(_parseDateTime(row['deleted_at'])),
      syncStatus: const Value('synced'),
      remoteVersion: Value(row['local_version'] as int? ?? 1),
      lastSyncedAt: Value(syncedAt),
      updatedAt: Value(_parseDateTime(row['updated_at']) ?? syncedAt),
      createdAt: Value(_parseDateTime(row['created_at']) ?? syncedAt),
    );
  }

  GoalsTableCompanion _goalFromRemote(
    Map<String, dynamic> row,
    DateTime syncedAt,
  ) {
    return GoalsTableCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String? ?? _userId),
      title: Value(row['title'] as String),
      goalType: Value(row['goal_type'] as String? ?? 'stage'),
      status: Value(row['status'] as String? ?? 'active'),
      progressMode: Value(row['progress_mode'] as String? ?? 'mixed'),
      todoWeight: Value(
        (row['todo_weight'] as num?)?.toDouble() ?? 0.7,
      ),
      habitWeight: Value(
        (row['habit_weight'] as num?)?.toDouble() ?? 0.3,
      ),
      todoUnitWeight: Value(
        (row['todo_unit_weight'] as num?)?.toDouble() ?? 1.0,
      ),
      habitUnitWeight: Value(
        (row['habit_unit_weight'] as num?)?.toDouble() ?? 0.5,
      ),
      progressTarget: Value(
        (row['progress_target'] as num?)?.toDouble(),
      ),
      progressValue: Value(
        (row['progress_value'] as num?)?.toDouble(),
      ),
      unit: Value(row['unit'] as String?),
      deletedAt: Value(_parseDateTime(row['deleted_at'])),
      syncStatus: const Value('synced'),
      remoteVersion: Value(row['local_version'] as int? ?? 1),
      lastSyncedAt: Value(syncedAt),
      updatedAt: Value(_parseDateTime(row['updated_at']) ?? syncedAt),
      createdAt: Value(_parseDateTime(row['created_at']) ?? syncedAt),
    );
  }

  NotesTableCompanion _noteFromRemote(
    Map<String, dynamic> row,
    DateTime syncedAt,
  ) {
    return NotesTableCompanion(
      id: Value(row['id'] as String),
      userId: Value(row['user_id'] as String? ?? _userId),
      title: Value(row['title'] as String?),
      content: Value(row['content'] as String? ?? ''),
      noteType: Value(row['note_type'] as String? ?? 'note'),
      isFavorite: Value(row['is_favorite'] as bool? ?? false),
      relatedEntityType: Value(row['related_entity_type'] as String?),
      relatedEntityId: Value(row['related_entity_id'] as String?),
      deletedAt: Value(_parseDateTime(row['deleted_at'])),
      syncStatus: const Value('synced'),
      remoteVersion: Value(row['local_version'] as int? ?? 1),
      lastSyncedAt: Value(syncedAt),
      updatedAt: Value(_parseDateTime(row['updated_at']) ?? syncedAt),
      createdAt: Value(_parseDateTime(row['created_at']) ?? syncedAt),
    );
  }

  // ---------------------------------------------------------------------------
  // Sync metadata helpers (stored in app_settings using namespaced keys)
  // ---------------------------------------------------------------------------

  String _lastPullKey(String entityType) =>
      'sync_last_pull_${_userId}_$entityType';

  Future<DateTime?> _lastPulledAt(String entityType) async {
    final key = _lastPullKey(entityType);
    final row = await (_database.select(_database.appSettingsTable)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    if (row?.value == null) return null;
    return DateTime.tryParse(row!.value!);
  }

  Future<void> _updateLastPulledAt(String entityType) async {
    final key = _lastPullKey(entityType);
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.into(_database.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion(
            key: Value(key),
            value: Value(now),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Queue status helpers
  // ---------------------------------------------------------------------------

  Future<void> _markDone(String queueId) async {
    await (_database.update(_database.syncQueueTable)
          ..where((tbl) => tbl.id.equals(queueId)))
        .write(
      SyncQueueTableCompanion(
        status: const Value('done'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _markFailed(SyncQueueTableData item, String error) async {
    final nextRetry = DateTime.now()
        .toUtc()
        .add(Duration(minutes: _backoffMinutes(item.retryCount)));
    await (_database.update(_database.syncQueueTable)
          ..where((tbl) => tbl.id.equals(item.id)))
        .write(
      SyncQueueTableCompanion(
        status: const Value('failed'),
        retryCount: Value(item.retryCount + 1),
        lastError: Value(error),
        nextRetryAt: Value(nextRetry),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  int _backoffMinutes(int retryCount) {
    const caps = <int>[1, 5, 15, 60, 240];
    final index = retryCount.clamp(0, caps.length - 1);
    return caps[index];
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  static String _tableNameFor(String entityType) {
    switch (entityType) {
      case 'todo':
        return 'todos';
      case 'schedule':
        return 'schedules';
      case 'habit':
        return 'habits';
      case 'anniversary':
        return 'anniversaries';
      case 'goal':
        return 'goals';
      case 'note':
        return 'notes';
      case 'timeline_event':
        return 'timeline_events';
      default:
        return entityType;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
