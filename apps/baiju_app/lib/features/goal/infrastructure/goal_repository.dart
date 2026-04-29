import 'dart:async';
import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/goal_dao.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class GoalRepository {
  GoalRepository(
    this._database,
    this._dao, {
    UserWorkspace? workspace,
    Uuid? uuid,
  })  : _workspace = workspace ?? const UserWorkspace.local(),
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final GoalDao _dao;
  final UserWorkspace _workspace;
  final Uuid _uuid;

  Stream<List<GoalOverview>> watchGoalOverviews() {
    return Stream<List<GoalOverview>>.multi((controller) {
      List<GoalsTableData> goals = const <GoalsTableData>[];
      List<TodosTableData> todos = const <TodosTableData>[];
      List<HabitsTableData> habits = const <HabitsTableData>[];
      List<HabitRecordsTableData> habitRecords = const <HabitRecordsTableData>[];

      void emit() {
        final today = DateTime.now().toUtc();
        final todayDate = DateTime(today.year, today.month, today.day).toUtc();

        final overviews = goals.map((goal) {
          final linkedTodos =
              todos.where((todo) => todo.goalId == goal.id).toList();
          final linkedHabits =
              habits.where((habit) => habit.goalId == goal.id).toList();
          final linkedHabitIds = linkedHabits.map((habit) => habit.id).toSet();

          final checkedHabitRecords = habitRecords.where((record) {
            final recordDate = DateTime(
              record.recordDate.year,
              record.recordDate.month,
              record.recordDate.day,
            ).toUtc();
            return linkedHabitIds.contains(record.habitId) &&
                record.status == 'done' &&
                recordDate == todayDate;
          }).toList();

          final totalHabitWeight = linkedHabits.fold<double>(
            0,
            (sum, habit) => sum + habit.progressWeight,
          );
          final checkedHabitWeight = checkedHabitRecords.fold<double>(
            0,
            (sum, record) {
              final habit = linkedHabits.firstWhere(
                (item) => item.id == record.habitId,
              );
              return sum + habit.progressWeight;
            },
          );

          return GoalOverview(
            goal: goal,
            linkedTodoCount: linkedTodos.length,
            completedTodoCount:
                linkedTodos.where((todo) => todo.status == 'completed').length,
            linkedHabitCount: linkedHabits.length,
            checkedHabitCount: checkedHabitRecords.length,
            totalHabitWeight: totalHabitWeight,
            checkedHabitWeight: checkedHabitWeight,
          );
        }).toList();

        controller.add(overviews);
      }

      final subscriptions = <StreamSubscription<dynamic>>[
        _dao.watchGoals().listen((value) {
          goals = value;
          emit();
        }),
        _dao.watchTodosForGoalStats().listen((value) {
          todos = value;
          emit();
        }),
        _dao.watchHabitsForGoalStats().listen((value) {
          habits = value;
          emit();
        }),
        _dao.watchHabitRecordsForGoalStats().listen((value) {
          habitRecords = value;
          emit();
        }),
      ];

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Stream<List<GoalTrendPoint>> watchGoalTrend(String goalId) {
    return Stream<List<GoalTrendPoint>>.multi((controller) {
      List<TodosTableData> todos = const <TodosTableData>[];
      List<HabitsTableData> habits = const <HabitsTableData>[];
      List<HabitRecordsTableData> habitRecords = const <HabitRecordsTableData>[];

      void emit() {
        final now = DateTime.now().toUtc();
        final today = DateTime(now.year, now.month, now.day).toUtc();
        final start = today.subtract(const Duration(days: 6));

        final points = List<GoalTrendPoint>.generate(7, (index) {
          final day = start.add(Duration(days: index));
          final nextDay = day.add(const Duration(days: 1));

          final completedTodos = todos.where((todo) {
            final completedAt = todo.completedAt;
            return todo.goalId == goalId &&
                completedAt != null &&
                completedAt.isAfter(day.subtract(const Duration(milliseconds: 1))) &&
                completedAt.isBefore(nextDay);
          }).length;

          final linkedHabitIds = habits
              .where((habit) => habit.goalId == goalId)
              .map((habit) => habit.id)
              .toSet();

          final checkedHabits = habitRecords.where((record) {
            final recordDate = DateTime(
              record.recordDate.year,
              record.recordDate.month,
              record.recordDate.day,
            ).toUtc();
            return linkedHabitIds.contains(record.habitId) &&
                record.status == 'done' &&
                recordDate == day;
          }).length;

          return GoalTrendPoint(
            date: day,
            completedTodos: completedTodos,
            checkedHabits: checkedHabits,
          );
        });

        controller.add(points);
      }

      final subscriptions = <StreamSubscription<dynamic>>[
        _dao.watchTodosForGoalStats().listen((value) {
          todos = value;
          emit();
        }),
        _dao.watchHabitsForGoalStats().listen((value) {
          habits = value;
          emit();
        }),
        _dao.watchHabitRecordsForGoalStats().listen((value) {
          habitRecords = value;
          emit();
        }),
      ];

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Future<void> createGoal({
    required String title,
    required GoalType goalType,
    required GoalProgressMode progressMode,
    required double todoWeight,
    required double habitWeight,
    required double todoUnitWeight,
    required double habitUnitWeight,
    required double? progressTarget,
    required String? unit,
    TodoPriority priority = TodoPriority.notUrgentImportant,
    DateTime? startDate,
  }) async {
    final now = DateTime.now().toUtc();
    final goalId = _uuid.v4();

    final companion = GoalsTableCompanion.insert(
      id: goalId,
      userId: _workspace.userId,
      title: title.trim(),
      goalType: Value(goalType.value),
      progressMode: Value(progressMode.value),
      todoWeight: Value(todoWeight),
      habitWeight: Value(habitWeight),
      todoUnitWeight: Value(todoUnitWeight),
      habitUnitWeight: Value(habitUnitWeight),
      status: const Value('active'),
      priority: Value(priority.value),
      progressValue: const Value(0.0),
      progressTarget: Value(progressTarget),
      unit: Value(unit),
      startDate: Value(startDate?.toUtc()),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending_create'),
      localVersion: const Value(1),
      deviceId: Value(_workspace.deviceId),
    );

    await _database.transaction(() async {
      await _dao.insertGoal(companion);
      await _enqueueSync(
        entityId: goalId,
        operation: 'create',
        payload: <String, Object?>{
          'id': goalId,
          'title': title.trim(),
          'goal_type': goalType.value,
          'progress_mode': progressMode.value,
          'todo_weight': todoWeight,
          'habit_weight': habitWeight,
          'todo_unit_weight': todoUnitWeight,
          'habit_unit_weight': habitUnitWeight,
          'priority': priority.value,
          'progress_target': progressTarget,
          'unit': unit,
          'updated_at': now.toIso8601String(),
        },
      );
      await _appendTimelineEvent(
        sourceEntityId: goalId,
        action: 'created',
        title: title.trim(),
        summary: '新增了一个目标',
        occurredAt: now,
      );
    });
  }

  Future<void> updateGoal({
    required GoalsTableData goal,
    required String title,
    required GoalType goalType,
    required GoalProgressMode progressMode,
    required double todoWeight,
    required double habitWeight,
    required double todoUnitWeight,
    required double habitUnitWeight,
    required GoalStatus status,
    required double? progressValue,
    required double? progressTarget,
    required String? unit,
    TodoPriority priority = TodoPriority.notUrgentImportant,
  }) async {
    final now = DateTime.now().toUtc();
    final nextVersion = goal.localVersion + 1;

    await _database.transaction(() async {
      await _dao.updateGoal(
        id: goal.id,
        title: title.trim(),
        description: goal.description,
        goalType: goalType.value,
        progressMode: progressMode.value,
        todoWeight: todoWeight,
        habitWeight: habitWeight,
        todoUnitWeight: todoUnitWeight,
        habitUnitWeight: habitUnitWeight,
        status: status.value,
        priority: priority.value,
        startDate: goal.startDate,
        endDate: goal.endDate,
        progressValue: progressValue,
        progressTarget: progressTarget,
        unit: unit,
        updatedAt: now,
        localVersion: nextVersion,
      );

      await _enqueueSync(
        entityId: goal.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': goal.id,
          'title': title.trim(),
          'goal_type': goalType.value,
          'progress_mode': progressMode.value,
          'todo_weight': todoWeight,
          'habit_weight': habitWeight,
          'todo_unit_weight': todoUnitWeight,
          'habit_unit_weight': habitUnitWeight,
          'status': status.value,
          'priority': priority.value,
          'progress_value': progressValue,
          'progress_target': progressTarget,
          'unit': unit,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: goal.id,
        action: 'updated',
        title: title.trim(),
        summary: '更新了一个目标',
        occurredAt: now,
      );
    });
  }

  Future<void> rescheduleGoal(GoalsTableData goal, DateTime newStartDate) async {
    final now = DateTime.now().toUtc();
    final nextVersion = goal.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.goalsTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(goal.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        GoalsTableCompanion(
          startDate: Value(newStartDate.toUtc()),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: goal.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': goal.id,
          'start_date': newStartDate.toUtc().toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );
    });
  }

  Future<void> setGoalPaused(GoalsTableData goal, bool paused) {    return _updateGoalStatus(
      goal: goal,
      status: paused ? GoalStatus.paused : GoalStatus.active,
      action: paused ? 'paused' : 'resumed',
      summary: paused ? '暂停了一个目标' : '恢复了一个目标',
    );
  }

  Future<void> archiveGoal(GoalsTableData goal) {
    return _updateGoalStatus(
      goal: goal,
      status: GoalStatus.abandoned,
      action: 'archived',
      summary: '归档了一个目标',
    );
  }

  Future<void> deleteGoal(GoalsTableData goal) async {
    final now = DateTime.now().toUtc();
    final nextVersion = goal.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.goalsTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(goal.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        GoalsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending_delete'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: goal.id,
        operation: 'delete',
        payload: <String, Object?>{
          'id': goal.id,
          'deleted_at': now.toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: goal.id,
        action: 'deleted',
        title: goal.title,
        summary: '删除了一个目标',
        occurredAt: now,
      );
    });
  }

  Future<void> _updateGoalStatus({
    required GoalsTableData goal,
    required GoalStatus status,
    required String action,
    required String summary,
  }) async {
    final now = DateTime.now().toUtc();
    final nextVersion = goal.localVersion + 1;

    await _database.transaction(() async {
      await (_database.update(_database.goalsTable)
            ..where(
              (tbl) =>
                  tbl.id.equals(goal.id) & tbl.userId.equals(_workspace.userId),
            ))
          .write(
        GoalsTableCompanion(
          status: Value(status.value),
          updatedAt: Value(now),
          syncStatus: const Value('pending_update'),
          localVersion: Value(nextVersion),
          deviceId: Value(_workspace.deviceId),
        ),
      );

      await _enqueueSync(
        entityId: goal.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': goal.id,
          'status': status.value,
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: goal.id,
        action: action,
        title: goal.title,
        summary: summary,
        occurredAt: now,
      );
    });
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
            entityType: 'goal',
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
    return _database.into(_database.timelineEventsTable).insert(
          TimelineEventsTableCompanion.insert(
            id: _uuid.v4(),
            userId: _workspace.userId,
            eventType: 'goal',
            eventAction: action,
            sourceEntityId: sourceEntityId,
            sourceEntityType: 'goal',
            occurredAt: occurredAt,
            title: title,
            summary: Value(summary),
            payloadJson: Value(
              jsonEncode(
                <String, Object?>{
                  'action': action,
                  'title': title,
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
}
