import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/goal_dao.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/infrastructure/goal_repository.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalDaoProvider = Provider<GoalDao>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return GoalDao(database, workspace);
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final dao = ref.watch(goalDaoProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return GoalRepository(database, dao, workspace: workspace);
});

final goalOverviewListProvider = StreamProvider.autoDispose<List<GoalOverview>>(
  (ref) {
    final repository = ref.watch(goalRepositoryProvider);
    return repository.watchGoalOverviews();
  },
);

final goalOptionsProvider = StreamProvider.autoDispose<List<GoalsTableData>>((
  ref,
) {
  final repository = ref.watch(goalRepositoryProvider);
  return repository.watchGoalOverviews().map(
    (items) => items.map((item) => item.goal).toList(),
  );
});

final goalDetailProvider = StreamProvider.family
    .autoDispose<GoalsTableData?, String>((ref, goalId) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      return (database.select(database.goalsTable)..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(workspace.userId) &
                tbl.id.equals(goalId),
          ))
          .watchSingleOrNull();
    });

final goalSummaryProvider = StreamProvider.autoDispose<GoalSummary>((ref) {
  final repository = ref.watch(goalRepositoryProvider);
  return repository.watchGoalOverviews().map((items) {
    final active = items.where((item) => item.goal.status == 'active').length;
    final completed = items
        .where((item) => item.goal.status == 'completed')
        .length;
    return GoalSummary(
      total: items.length,
      active: active,
      completed: completed,
    );
  });
});

final goalTrendProvider = StreamProvider.family
    .autoDispose<List<GoalTrendPoint>, String>((ref, goalId) {
      final repository = ref.watch(goalRepositoryProvider);
      return repository.watchGoalTrend(goalId);
    });

final goalActionsProvider = Provider<GoalActions>((ref) {
  final repository = ref.watch(goalRepositoryProvider);
  return GoalActions(repository);
});

class GoalActions {
  const GoalActions(this._repository);

  final GoalRepository _repository;

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
  }) {
    return _repository.createGoal(
      title: title,
      goalType: goalType,
      progressMode: progressMode,
      todoWeight: todoWeight,
      habitWeight: habitWeight,
      todoUnitWeight: todoUnitWeight,
      habitUnitWeight: habitUnitWeight,
      progressTarget: progressTarget,
      unit: unit,
    );
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
  }) {
    return _repository.updateGoal(
      goal: goal,
      title: title,
      goalType: goalType,
      progressMode: progressMode,
      todoWeight: todoWeight,
      habitWeight: habitWeight,
      todoUnitWeight: todoUnitWeight,
      habitUnitWeight: habitUnitWeight,
      status: status,
      progressValue: progressValue,
      progressTarget: progressTarget,
      unit: unit,
    );
  }

  Future<void> setGoalPaused(GoalsTableData goal, bool paused) {
    return _repository.setGoalPaused(goal, paused);
  }

  Future<void> archiveGoal(GoalsTableData goal) {
    return _repository.archiveGoal(goal);
  }

  Future<void> deleteGoal(GoalsTableData goal) {
    return _repository.deleteGoal(goal);
  }
}

final goalTodoDetailsProvider = StreamProvider.family
    .autoDispose<List<TodosTableData>, String>((ref, goalId) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      final query = database.select(database.todosTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.goalId.equals(goalId),
        )
        ..orderBy(<OrderingTerm Function($TodosTableTable)>[
          (tbl) => OrderingTerm.desc(tbl.updatedAt),
        ]);

      return query.watch();
    });

final goalHabitDetailsProvider = StreamProvider.family
    .autoDispose<List<HabitTodayItem>, String>((ref, goalId) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);

      return (database.select(database.habitsTable)..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(workspace.userId) &
                tbl.goalId.equals(goalId),
          ))
          .watch()
          .asyncMap((habits) async {
            final now = DateTime.now().toUtc();
            final start = DateTime(now.year, now.month, now.day).toUtc();
            final end = start.add(const Duration(days: 1));
            final habitIds = habits.map((habit) => habit.id).toList();

            final records = habitIds.isEmpty
                ? <HabitRecordsTableData>[]
                : await (database.select(database.habitRecordsTable)..where(
                        (tbl) =>
                            tbl.deletedAt.isNull() &
                            tbl.userId.equals(workspace.userId) &
                            tbl.habitId.isIn(habitIds) &
                            tbl.recordDate.isBiggerOrEqualValue(start) &
                            tbl.recordDate.isSmallerThanValue(end),
                      ))
                      .get();

            final recordsByHabit = <String, HabitRecordsTableData>{
              for (final record in records) record.habitId: record,
            };

            var items = habits
                .map(
                  (habit) => HabitTodayItem(
                    habit: habit,
                    checkedToday: recordsByHabit[habit.id]?.status == 'done',
                    record: recordsByHabit[habit.id],
                  ),
                )
                .toList();
            return items;
          });
    });
