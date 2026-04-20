import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class TodoRepository {
  TodoRepository(
    this._database, {
    UserWorkspace? workspace,
    Uuid? uuid,
  })  : _workspace = workspace ?? const UserWorkspace.local(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final UserWorkspace _workspace;
  final Uuid _uuid;

  Stream<List<TodoSubtasksTableData>> watchTodoSubtasks(String todoId) {
    final query = _database.select(_database.todoSubtasksTable)
      ..where(
        (tbl) =>
            tbl.deletedAt.isNull() &
            tbl.userId.equals(_workspace.userId) &
            tbl.todoId.equals(todoId),
      );

    return query.watch().map((rows) {
      final subtasks = rows.toList()
        ..sort(
          (left, right) =>
              left.sortOrder.compareTo(right.sortOrder) != 0
                  ? left.sortOrder.compareTo(right.sortOrder)
                  : left.createdAt.compareTo(right.createdAt),
        );
      return subtasks;
    });
  }

  Stream<List<TodosTableData>> watchTodos(TodoFilter filter) {
    final query = _database.select(_database.todosTable)
      ..where(
        (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
      );

    switch (filter) {
      case TodoFilter.all:
        break;
      case TodoFilter.active:
        query.where(
          (tbl) => tbl.status.isNotValue('completed') &
              tbl.status.isNotValue('archived'),
        );
      case TodoFilter.today:
        final range = _todayRangeUtc();
        query.where(
          (tbl) => tbl.status.isNotValue('completed') &
              tbl.status.isNotValue('archived') &
              tbl.dueAt.isNotNull() &
              tbl.dueAt.isBiggerOrEqualValue(range.start) &
              tbl.dueAt.isSmallerThanValue(range.end),
        );
      case TodoFilter.completed:
        query.where((tbl) => tbl.status.equals('completed'));
    }

    return query.watch().map((rows) {
      final todos = rows.toList()..sort(_compareTodos);
      return todos;
    });
  }

  Future<void> createTodo({
    required String title,
    required TodoPriority priority,
    required bool dueToday,
    String? goalId,
    DateTime? dueAt,
  }) async {
    final now = DateTime.now().toUtc();
    final todoId = _uuid.v4();
    final resolvedDueAt = dueAt ??
        (dueToday ? _todayRangeUtc().end.subtract(const Duration(minutes: 1)) : null);

    final companion = TodosTableCompanion.insert(
      id: todoId,
      userId: _workspace.userId,
      title: title.trim(),
      priority: Value(priority.value),
      dueAt: Value(resolvedDueAt),
      plannedAt: Value(resolvedDueAt),
      goalId: Value(goalId),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending_create'),
      localVersion: const Value(1),
      deviceId: Value(_workspace.deviceId),
    );

    await _database.transaction(() async {
      await _database.into(_database.todosTable).insert(companion);
      await _enqueueSync(
        entityId: todoId,
        operation: 'create',
        payload: <String, Object?>{
          'id': todoId,
          'title': title.trim(),
          'priority': priority.value,
          'goal_id': goalId,
          'due_at': resolvedDueAt?.toIso8601String(),
          'status': 'open',
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        sourceEntityId: todoId,
        action: 'created',
        title: title.trim(),
        summary: '新增了一条待办',
        occurredAt: now,
      );
    });
  }

  Future<String> createTodoFromSchedule({
    required SchedulesTableData schedule,
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueAt,
  }) async {
    final now = DateTime.now().toUtc();
    final todoId = _uuid.v4();
    final normalizedTitle = schedule.title.trim();
    final plannedAt = schedule.startAt;
    final normalizedDueAt = dueAt ?? schedule.startAt;
    final normalizedDescription = _buildScheduleLinkedDescription(schedule);

    final companion = TodosTableCompanion.insert(
      id: todoId,
      userId: _workspace.userId,
      title: normalizedTitle,
      description: Value(normalizedDescription),
      priority: Value(priority.value),
      dueAt: Value(normalizedDueAt),
      plannedAt: Value(plannedAt),
      convertedScheduleId: Value(schedule.id),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending_create'),
      localVersion: const Value(1),
      deviceId: Value(_workspace.deviceId),
    );

    await _database.transaction(() async {
      await _database.into(_database.todosTable).insert(companion);
      await _enqueueSync(
        entityId: todoId,
        operation: 'create',
        payload: <String, Object?>{
          'id': todoId,
          'title': normalizedTitle,
          'description': normalizedDescription,
          'priority': priority.value,
          'due_at': normalizedDueAt.toIso8601String(),
          'planned_at': plannedAt.toIso8601String(),
          'converted_schedule_id': schedule.id,
          'source_schedule_id': schedule.id,
          'status': 'open',
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        sourceEntityId: todoId,
        action: 'created_from_schedule',
        title: normalizedTitle,
        summary: 'Created a todo from schedule',
        occurredAt: now,
        payload: <String, Object?>{
          'source_schedule_id': schedule.id,
        },
      );
    });

    return todoId;
  }

  Future<void> createTodoSubtask({
    required String todoId,
    required String title,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }

    final todo = await (_database.select(_database.todosTable)
          ..where(
            (tbl) =>
                tbl.id.equals(todoId) &
                tbl.userId.equals(_workspace.userId) &
                tbl.deletedAt.isNull(),
          ))
        .getSingleOrNull();

    if (todo == null) {
      return;
    }

    final now = DateTime.now().toUtc();
    final subtaskId = _uuid.v4();
    final nextSortOrder = await _nextSubtaskSortOrder(todoId);
    await _database.into(_database.todoSubtasksTable).insert(
          TodoSubtasksTableCompanion.insert(
            id: subtaskId,
            todoId: todoId,
            userId: _workspace.userId,
            title: trimmedTitle,
            sortOrder: Value(nextSortOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('pending_create'),
            localVersion: const Value(1),
            deviceId: Value(_workspace.deviceId),
          ),
        );
  }

  Future<void> toggleTodoSubtaskCompletion(
    TodoSubtasksTableData subtask,
    bool completed,
  ) async {
    final now = DateTime.now().toUtc();
    final nextVersion = subtask.localVersion + 1;
    await (_database.update(_database.todoSubtasksTable)
          ..where(
            (tbl) =>
                tbl.id.equals(subtask.id) &
                tbl.userId.equals(_workspace.userId),
          ))
        .write(
      TodoSubtasksTableCompanion(
        isCompleted: Value(completed),
        updatedAt: Value(now),
        syncStatus: Value(_resolvePendingUpdateSyncStatus(subtask.syncStatus)),
        localVersion: Value(nextVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }

  Future<void> deleteTodoSubtask(TodoSubtasksTableData subtask) async {
    final now = DateTime.now().toUtc();
    final nextVersion = subtask.localVersion + 1;
    await (_database.update(_database.todoSubtasksTable)
          ..where(
            (tbl) =>
                tbl.id.equals(subtask.id) &
                tbl.userId.equals(_workspace.userId),
          ))
        .write(
      TodoSubtasksTableCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending_delete'),
        localVersion: Value(nextVersion),
        deviceId: Value(_workspace.deviceId),
      ),
    );
  }

  Future<void> toggleTodoCompletion(
    TodosTableData todo,
    bool completed,
  ) async {
    final now = DateTime.now().toUtc();
    final nextStatus = completed ? 'completed' : 'open';
    final nextVersion = todo.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.todosTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(todo.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        TodosTableCompanion(
          status: Value(nextStatus),
          completedAt: Value(completed ? now : null),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: todo.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': todo.id,
          'status': nextStatus,
          'completed_at': completed ? now.toIso8601String() : null,
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: todo.id,
        action: completed ? 'completed' : 'reopened',
        title: todo.title,
        summary: completed ? '完成了一条待办' : '重新打开了一条待办',
        occurredAt: now,
      );
    });
  }

  Future<void> markTodoScheduled({
    required TodosTableData todo,
    required String scheduleId,
    required DateTime startAt,
  }) async {
    final now = DateTime.now().toUtc();
    final nextVersion = todo.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.todosTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(todo.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        TodosTableCompanion(
          convertedScheduleId: Value(scheduleId),
          plannedAt: Value(startAt),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: todo.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': todo.id,
          'converted_schedule_id': scheduleId,
          'planned_at': startAt.toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: todo.id,
        action: 'scheduled',
        title: todo.title,
        summary: '把待办转成了日程',
        occurredAt: now,
      );
    });
  }

  Future<void> updateTodo({
    required TodosTableData todo,
    required String title,
    required TodoPriority priority,
    required DateTime? dueAt,
  }) async {
    final now = DateTime.now().toUtc();
    final nextVersion = todo.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.todosTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(todo.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        TodosTableCompanion(
          title: Value(title.trim()),
          priority: Value(priority.value),
          dueAt: Value(dueAt),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: todo.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': todo.id,
          'title': title.trim(),
          'priority': priority.value,
          'due_at': dueAt?.toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: todo.id,
        action: 'updated',
        title: title.trim(),
        summary: '更新了一条待办',
        occurredAt: now,
      );
    });
  }

  Future<void> archiveTodo(TodosTableData todo) async {
    final now = DateTime.now().toUtc();
    final nextVersion = todo.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.todosTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(todo.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        TodosTableCompanion(
          status: const Value('archived'),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: todo.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': todo.id,
          'status': 'archived',
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: todo.id,
        action: 'archived',
        title: todo.title,
        summary: '归档了一条待办',
        occurredAt: now,
      );
    });
  }

  Future<void> deleteTodo(TodosTableData todo) async {
    final now = DateTime.now().toUtc();
    final nextVersion = todo.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.todosTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(todo.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        TodosTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending_delete'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: todo.id,
        operation: 'delete',
        payload: <String, Object?>{
          'id': todo.id,
          'deleted_at': now.toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: todo.id,
        action: 'deleted',
        title: todo.title,
        summary: '删除了一条待办',
        occurredAt: now,
      );
    });
  }

  Future<int> rolloverOverdueTodosToToday() async {
    final now = DateTime.now().toUtc();
    final todayRange = _todayRangeUtc();
    final todayDueAt = todayRange.end.subtract(const Duration(minutes: 1));
    final overdueTodos = await (_database.select(_database.todosTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_workspace.userId) &
                tbl.status.isNotValue('completed') &
                tbl.status.isNotValue('archived') &
                tbl.dueAt.isNotNull() &
                tbl.dueAt.isSmallerThanValue(todayRange.start),
          ))
        .get();

    if (overdueTodos.isEmpty) {
      return 0;
    }

    await _database.transaction(() async {
      for (final todo in overdueTodos) {
        final nextVersion = todo.localVersion + 1;
        await (_database.update(_database.todosTable)
              ..where(
                (tbl) =>
                    tbl.id.equals(todo.id) &
                    tbl.userId.equals(_workspace.userId),
              ))
            .write(
          TodosTableCompanion(
            dueAt: Value(todayDueAt),
            plannedAt: Value(todayDueAt),
            updatedAt: Value(now),
            syncStatus: const Value('pending_update'),
            localVersion: Value(nextVersion),
            deviceId: Value(_workspace.deviceId),
          ),
        );

        await _enqueueSync(
          entityId: todo.id,
          operation: 'update',
          payload: <String, Object?>{
            'id': todo.id,
            'due_at': todayDueAt.toIso8601String(),
            'planned_at': todayDueAt.toIso8601String(),
            'local_version': nextVersion,
            'updated_at': now.toIso8601String(),
          },
        );

        await _appendTimelineEvent(
          sourceEntityId: todo.id,
          action: 'rolled_over',
          title: todo.title,
          summary: '将未完成待办顺延到了今天',
          occurredAt: now,
        );
      }
    });

    return overdueTodos.length;
  }

  Future<void> _enqueueSync({
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) async {
    await _database.into(_database.syncQueueTable).insert(
          SyncQueueTableCompanion.insert(
            id: _uuid.v4(),
            userId: Value(_workspace.userId),
            entityType: 'todo',
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
    Map<String, Object?>? payload,
  }) async {
    await _database.into(_database.timelineEventsTable).insert(
          TimelineEventsTableCompanion.insert(
            id: _uuid.v4(),
            userId: _workspace.userId,
            eventType: 'todo',
            eventAction: action,
            sourceEntityId: sourceEntityId,
            sourceEntityType: 'todo',
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

  String? _buildScheduleLinkedDescription(SchedulesTableData schedule) {
    final description = schedule.description?.trim();
    final location = schedule.location?.trim();
    final category = schedule.category?.trim();
    final parts = <String>[
      if (description != null && description.isNotEmpty) description,
      if (location != null && location.isNotEmpty) 'Location: $location',
      if (category != null && category.isNotEmpty) 'Category: $category',
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('\n');
  }

  int _compareTodos(TodosTableData left, TodosTableData right) {
    final leftCompleted = left.status == 'completed';
    final rightCompleted = right.status == 'completed';

    if (leftCompleted != rightCompleted) {
      return leftCompleted ? 1 : -1;
    }

    if (!leftCompleted) {
      final dueComparison = _compareNullableDates(left.dueAt, right.dueAt);
      if (dueComparison != 0) {
        return dueComparison;
      }

      final priorityComparison =
          _priorityRank(right.priority).compareTo(_priorityRank(left.priority));
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      return right.updatedAt.compareTo(left.updatedAt);
    }

    final leftCompletedAt = left.completedAt ?? left.updatedAt;
    final rightCompletedAt = right.completedAt ?? right.updatedAt;
    return rightCompletedAt.compareTo(leftCompletedAt);
  }

  int _compareNullableDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left.compareTo(right);
  }

  int _priorityRank(String priority) {
    switch (priority) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
      default:
        return 1;
    }
  }

  _UtcRange _todayRangeUtc() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = DateTime(now.year, now.month, now.day + 1).toUtc();
    return _UtcRange(start: start, end: end);
  }

  Future<int> _nextSubtaskSortOrder(String todoId) async {
    final rows = await (_database.select(_database.todoSubtasksTable)
          ..where(
            (tbl) =>
                tbl.todoId.equals(todoId) &
                tbl.userId.equals(_workspace.userId) &
                tbl.deletedAt.isNull(),
          ))
        .get();
    if (rows.isEmpty) {
      return 0;
    }
    return rows
            .map((subtask) => subtask.sortOrder)
            .reduce((left, right) => left > right ? left : right) +
        1;
  }

  String _resolvePendingUpdateSyncStatus(String currentStatus) {
    if (currentStatus == 'pending_create') {
      return 'pending_create';
    }
    return 'pending_update';
  }
}

class _UtcRange {
  const _UtcRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}
