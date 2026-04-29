import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/habit_dao.dart';
import 'package:baiju_app/core/database/daos/schedule_dao.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/infrastructure/habit_repository.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/infrastructure/schedule_repository.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/infrastructure/todo_repository.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final scheduleDaoProvider = Provider<ScheduleDao>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return ScheduleDao(database, workspace);
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final dao = ref.watch(scheduleDaoProvider);
  final reminderScheduler = ref.watch(reminderSchedulerProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return ScheduleRepository(
    database,
    dao,
    reminderScheduler: reminderScheduler,
    workspace: workspace,
  );
});

final selectedScheduleFilterProvider =
    NotifierProvider<SelectedScheduleFilterNotifier, ScheduleFilter>(
  SelectedScheduleFilterNotifier.new,
);

final scheduleListProvider =
    StreamProvider.autoDispose<List<SchedulesTableData>>((ref) {
  final repository = ref.watch(scheduleRepositoryProvider);
  final filter = ref.watch(selectedScheduleFilterProvider);
  return repository.watchSchedules(filter);
});

final scheduleDetailProvider =
    StreamProvider.family.autoDispose<SchedulesTableData?, String>(
        (ref, scheduleId) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.schedulesTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.id.equals(scheduleId),
        ))
      .watchSingleOrNull();
});

final allScheduleListProvider =
    StreamProvider.autoDispose<List<SchedulesTableData>>((ref) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.watchSchedules(ScheduleFilter.all);
});

final todayScheduleListProvider =
    StreamProvider.autoDispose<List<SchedulesTableData>>((ref) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.watchSchedules(ScheduleFilter.today);
});

final scheduleSummaryProvider =
    StreamProvider.autoDispose<ScheduleSummary>((ref) {
  final repository = ref.watch(scheduleRepositoryProvider);
  return repository.watchSchedules(ScheduleFilter.all).map((schedules) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);

    var today = 0;
    var upcoming = 0;
    var completed = 0;

    for (final schedule in schedules) {
      if (schedule.status == 'completed') {
        completed++;
      }

      final localStart = schedule.startAt.toLocal();
      if (!localStart.isBefore(start) && localStart.isBefore(end)) {
        today++;
      }

      if (schedule.status == 'planned' &&
          schedule.startAt.isAfter(DateTime.now().toUtc())) {
        upcoming++;
      }
    }

    return ScheduleSummary(
      total: schedules.length,
      today: today,
      upcoming: upcoming,
      completed: completed,
    );
  });
});

final scheduleActionsProvider = Provider<ScheduleActions>((ref) {
  final scheduleRepository = ref.watch(scheduleRepositoryProvider);
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  final reminderScheduler = ref.watch(reminderSchedulerProvider);
  final todoRepository = TodoRepository(database, workspace: workspace);
  final habitRepository = HabitRepository(
    database,
    HabitDao(database, workspace),
    reminderScheduler: reminderScheduler,
    workspace: workspace,
  );
  return ScheduleActions(
    scheduleRepository,
    todoRepository,
    habitRepository,
  );
});

class ScheduleActions {
  const ScheduleActions(
    this._repository,
    this._todoRepository,
    this._habitRepository,
  );

  final ScheduleRepository _repository;
  final TodoRepository _todoRepository;
  final HabitRepository _habitRepository;

  Future<void> createSchedule({
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
    TodoPriority priority = TodoPriority.notUrgentImportant,
  }) {
    return _repository.createSchedule(
      title: title,
      day: day,
      slot: slot,
      duration: duration,
      reminder: reminder,
      recurrence: recurrence,
      description: description,
      location: location,
      category: category,
      isAllDay: isAllDay,
      priority: priority,
    );
  }

  Future<void> createScheduleAt({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    bool isAllDay = false,
    String? location,
    String? category,
    String? description,
    String? recurrenceRule,
    int? reminderMinutesBefore,
    TodoPriority priority = TodoPriority.notUrgentImportant,
  }) {
    return _repository.createScheduleAt(
      title: title,
      startAt: startAt,
      endAt: endAt,
      isAllDay: isAllDay,
      location: location,
      category: category,
      description: description,
      recurrenceRule: recurrenceRule,
      reminderMinutesBefore: reminderMinutesBefore,
      priority: priority,
    );
  }

  Future<void> toggleScheduleCompletion(
    SchedulesTableData schedule,
    bool completed,
  ) {
    return _repository.toggleScheduleCompletion(schedule, completed);
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
    TodoPriority? priority,
  }) {
    return _repository.updateSchedule(
      schedule: schedule,
      title: title,
      startAt: startAt,
      endAt: endAt,
      reminder: reminder,
      recurrence: recurrence,
      description: description,
      location: location,
      category: category,
      isAllDay: isAllDay,
      priority: priority,
    );
  }

  Future<void> cancelSchedule(SchedulesTableData schedule) {
    return _repository.cancelSchedule(schedule);
  }

  Future<void> deleteSchedule(SchedulesTableData schedule) {
    return _repository.deleteSchedule(schedule);
  }

  Future<String> convertScheduleToTodo({
    required SchedulesTableData schedule,
    TodoPriority priority = TodoPriority.notUrgentImportant,
    DateTime? dueAt,
  }) async {
    final todoId = await _todoRepository.createTodoFromSchedule(
      schedule: schedule,
      priority: priority,
      dueAt: dueAt,
    );
    await _repository.recordScheduleConvertedToTodo(
      schedule: schedule,
      todoId: todoId,
    );
    return todoId;
  }

  Future<String> convertToTodo({
    required SchedulesTableData schedule,
    TodoPriority priority = TodoPriority.notUrgentImportant,
    DateTime? dueAt,
  }) {
    return convertScheduleToTodo(
      schedule: schedule,
      priority: priority,
      dueAt: dueAt,
    );
  }

  Future<String> createTodoFromSchedule({
    required SchedulesTableData schedule,
    TodoPriority priority = TodoPriority.notUrgentImportant,
    DateTime? dueAt,
  }) {
    return convertScheduleToTodo(
      schedule: schedule,
      priority: priority,
      dueAt: dueAt,
    );
  }

  Future<String?> syncScheduleToHabitRecord({
    required SchedulesTableData schedule,
    HabitsTableData? habit,
    HabitRecordStatus status = HabitRecordStatus.done,
    DateTime? recordDate,
  }) async {
    final targetHabit = habit ?? await _resolveTargetHabit();
    if (targetHabit == null) {
      throw ArgumentError('habit is required');
    }
    final recordId = await _habitRepository.syncHabitRecordFromSchedule(
      habit: targetHabit,
      schedule: schedule,
      status: status,
      recordDate: recordDate,
    );
    if (recordId == null) {
      return null;
    }
    await _repository.recordScheduleSyncedToHabitRecord(
      schedule: schedule,
      habitId: targetHabit.id,
      habitRecordId: recordId,
      recordDate: recordDate ?? schedule.startAt,
      recordStatus: status.value,
    );
    return recordId;
  }

  Future<String?> syncToHabitRecord({
    required SchedulesTableData schedule,
    HabitsTableData? habit,
    HabitRecordStatus status = HabitRecordStatus.done,
    DateTime? recordDate,
  }) {
    return syncScheduleToHabitRecord(
      schedule: schedule,
      habit: habit,
      status: status,
      recordDate: recordDate,
    );
  }

  Future<String?> syncScheduleToHabit({
    required SchedulesTableData schedule,
    HabitsTableData? habit,
    HabitRecordStatus status = HabitRecordStatus.done,
    DateTime? recordDate,
  }) {
    return syncScheduleToHabitRecord(
      schedule: schedule,
      habit: habit,
      status: status,
      recordDate: recordDate,
    );
  }

  Future<SchedulesTableData> postponeScheduleByDays({
    required SchedulesTableData schedule,
    int days = 1,
  }) {
    return _repository.postponeScheduleByDays(
      schedule: schedule,
      days: days,
    );
  }

  Future<SchedulesTableData> postponeScheduleByOneDay(
    SchedulesTableData schedule,
  ) {
    return _repository.postponeScheduleByDays(schedule: schedule, days: 1);
  }

  Future<SchedulesTableData> postponeSchedule({
    required SchedulesTableData schedule,
    int days = 1,
    int? byDays,
  }) {
    return _repository.postponeScheduleByDays(
      schedule: schedule,
      days: byDays ?? days,
    );
  }

  Future<SchedulesTableData> delaySchedule({
    required SchedulesTableData schedule,
    int days = 1,
  }) {
    return _repository.postponeScheduleByDays(schedule: schedule, days: days);
  }

  Future<HabitsTableData?> _resolveTargetHabit() async {
    final habits = await _habitRepository.watchHabitsForToday().first;
    for (final item in habits) {
      if (item.habit.status == 'active') {
        return item.habit;
      }
    }
    if (habits.isEmpty) {
      return null;
    }
    return habits.first.habit;
  }
}

class SelectedScheduleFilterNotifier extends Notifier<ScheduleFilter> {
  @override
  ScheduleFilter build() {
    return ScheduleFilter.today;
  }

  void select(ScheduleFilter filter) {
    state = filter;
  }
}
