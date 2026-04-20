import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/database/daos/habit_dao.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/infrastructure/habit_repository.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final habitDaoProvider = Provider<HabitDao>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return HabitDao(database, workspace);
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final dao = ref.watch(habitDaoProvider);
  final reminderScheduler = ref.watch(reminderSchedulerProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return HabitRepository(
    database,
    dao,
    reminderScheduler: reminderScheduler,
    workspace: workspace,
  );
});

final habitListProvider = StreamProvider.autoDispose<List<HabitTodayItem>>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return repository.watchHabitsForToday();
});

final habitDetailProvider =
    StreamProvider.family.autoDispose<HabitsTableData?, String>((ref, habitId) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.habitsTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.id.equals(habitId),
        ))
      .watchSingleOrNull();
});

final habitSummaryProvider = StreamProvider.autoDispose<HabitSummary>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return repository.watchHabitsForToday().map((habits) {
    final active = habits.where((item) => item.habit.status == 'active').length;
    final checkedToday = habits.where((item) => item.checkedToday).length;
    return HabitSummary(
      total: habits.length,
      active: active,
      checkedToday: checkedToday,
    );
  });
});

final habitDetailInsightsProvider =
    StreamProvider.family.autoDispose<HabitDetailInsights, String>((
      ref,
      habitId,
    ) {
      final repository = ref.watch(habitRepositoryProvider);
      return repository.watchHabitDetailInsights(habitId, recentDays: 35);
    });

final habitCurrentStreakProvider = StreamProvider.autoDispose<int>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.habitRecordsTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.status.equals('done'),
        ))
      .watch()
      .map((records) {
    final now = DateTime.now();
    final todayDate = DateTime.utc(now.year, now.month, now.day);

    final recordsByHabit = <String, Set<DateTime>>{};
    for (final record in records) {
      final day = DateTime.utc(
        record.recordDate.year,
        record.recordDate.month,
        record.recordDate.day,
      );
      recordsByHabit.putIfAbsent(record.habitId, () => <DateTime>{}).add(day);
    }

    var bestStreak = 0;
    for (final days in recordsByHabit.values) {
      var streak = 0;
      var cursor = todayDate;
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      if (streak > bestStreak) {
        bestStreak = streak;
      }
    }

    return bestStreak;
  });
});

final habitActionsProvider = Provider<HabitActions>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return HabitActions(repository);
});

class HabitActions {
  const HabitActions(this._repository);

  final HabitRepository _repository;

  Future<void> createHabit({
    required String name,
    required String? reminderTime,
    String? goalId,
    double progressWeight = 1.0,
  }) {
    return _repository.createHabit(
      name: name,
      reminderTime: reminderTime,
      goalId: goalId,
      progressWeight: progressWeight,
    );
  }

  Future<void> toggleHabitCheckIn(HabitTodayItem item, bool checked) {
    return _repository.toggleHabitCheckIn(item, checked);
  }

  Future<void> updateHabit({
    required HabitsTableData habit,
    required String name,
    required String? reminderTime,
    String? goalId,
    double? progressWeight,
  }) {
    return _repository.updateHabit(
      habit: habit,
      name: name,
      reminderTime: reminderTime,
      goalId: goalId,
      progressWeight: progressWeight,
    );
  }

  Future<void> setHabitPaused(HabitsTableData habit, bool paused) {
    return _repository.setHabitPaused(habit, paused);
  }

  Future<void> deleteHabit(HabitsTableData habit) {
    return _repository.deleteHabit(habit);
  }

  Future<void> backfillHabitRecord({
    required HabitsTableData habit,
    required DateTime recordDate,
    required HabitRecordStatus status,
  }) {
    return _repository.backfillHabitRecord(
      habit: habit,
      recordDate: recordDate,
      status: status,
    );
  }

  Future<String?> syncHabitRecordFromSchedule({
    required HabitsTableData habit,
    required SchedulesTableData schedule,
    HabitRecordStatus status = HabitRecordStatus.done,
    DateTime? recordDate,
  }) {
    return _repository.syncHabitRecordFromSchedule(
      habit: habit,
      schedule: schedule,
      status: status,
      recordDate: recordDate,
    );
  }
}
