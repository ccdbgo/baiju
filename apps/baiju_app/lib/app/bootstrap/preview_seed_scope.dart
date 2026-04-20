import 'dart:async';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/database/daos/goal_dao.dart';
import 'package:baiju_app/core/database/daos/habit_dao.dart';
import 'package:baiju_app/core/database/daos/schedule_dao.dart';
import 'package:baiju_app/core/notifications/reminder_scheduler.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/infrastructure/goal_repository.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/infrastructure/habit_repository.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/infrastructure/schedule_repository.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/infrastructure/todo_repository.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final previewSeedControllerProvider = Provider<PreviewSeedController>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return PreviewSeedController(database, workspace);
});

class PreviewSeedScope extends ConsumerStatefulWidget {
  const PreviewSeedScope({
    required this.enabled,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Widget child;

  @override
  ConsumerState<PreviewSeedScope> createState() => _PreviewSeedScopeState();
}

class _PreviewSeedScopeState extends ConsumerState<PreviewSeedScope> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled && kIsWeb) {
      unawaited(ref.read(previewSeedControllerProvider).seedIfNeeded());
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class PreviewSeedController {
  PreviewSeedController(this._database, this._workspace);

  final AppDatabase _database;
  final UserWorkspace _workspace;

  Future<void> seedIfNeeded() async {
    final goalCount = await (_database.select(_database.goalsTable)
          ..where((tbl) => tbl.userId.equals(_workspace.userId)))
        .get()
        .then((v) => v.length);
    final todoCount = await (_database.select(_database.todosTable)
          ..where((tbl) => tbl.userId.equals(_workspace.userId)))
        .get()
        .then((v) => v.length);
    final habitCount = await (_database.select(_database.habitsTable)
          ..where((tbl) => tbl.userId.equals(_workspace.userId)))
        .get()
        .then((v) => v.length);
    final scheduleCount = await (_database.select(_database.schedulesTable)
          ..where((tbl) => tbl.userId.equals(_workspace.userId)))
        .get()
        .then((v) => v.length);

    if (goalCount + todoCount + habitCount + scheduleCount > 0) {
      return;
    }

    final goalRepo = GoalRepository(
      _database,
      GoalDao(_database, _workspace),
      workspace: _workspace,
    );
    final todoRepo = TodoRepository(
      _database,
      workspace: _workspace,
    );
    final habitRepo = HabitRepository(
      _database,
      HabitDao(_database, _workspace),
      workspace: _workspace,
    );
    final scheduleRepo = ScheduleRepository(
      _database,
      ScheduleDao(_database, _workspace),
      reminderScheduler: const NoopReminderScheduler(),
      workspace: _workspace,
    );

    await goalRepo.createGoal(
      title: '打造晨间系统',
      goalType: GoalType.stage,
      progressMode: GoalProgressMode.weightedMixed,
      todoWeight: 0.7,
      habitWeight: 0.3,
      todoUnitWeight: 1.0,
      habitUnitWeight: 0.5,
      progressTarget: null,
      unit: null,
    );
    await goalRepo.createGoal(
      title: '完成四月专题学习',
      goalType: GoalType.monthly,
      progressMode: GoalProgressMode.manual,
      todoWeight: 0.7,
      habitWeight: 0.3,
      todoUnitWeight: 1.0,
      habitUnitWeight: 0.5,
      progressTarget: 10,
      unit: '篇',
    );

    final goals = await (_database.select(_database.goalsTable)
          ..where((tbl) => tbl.userId.equals(_workspace.userId)))
        .get();
    final autoGoal = goals.firstWhere((goal) => goal.title == '打造晨间系统');
    final manualGoal = goals.firstWhere((goal) => goal.title == '完成四月专题学习');

    await todoRepo.createTodo(
      title: '整理今天重点任务',
      priority: TodoPriority.high,
      dueToday: true,
      goalId: autoGoal.id,
    );
    await todoRepo.createTodo(
      title: '提交阶段复盘',
      priority: TodoPriority.medium,
      dueToday: false,
      goalId: autoGoal.id,
    );
    await todoRepo.createTodo(
      title: '读完本周第三篇文章',
      priority: TodoPriority.low,
      dueToday: false,
      goalId: manualGoal.id,
    );

    final todos = await (_database.select(_database.todosTable)
          ..where((tbl) => tbl.userId.equals(_workspace.userId)))
        .get();
    final firstTodo =
        todos.firstWhere((todo) => todo.title == '整理今天重点任务');
    await todoRepo.toggleTodoCompletion(firstTodo, true);

    await habitRepo.createHabit(
      name: '晨间阅读',
      reminderTime: HabitReminderPreset.morning.value,
      goalId: autoGoal.id,
      progressWeight: 1.2,
    );
    await habitRepo.createHabit(
      name: '晚间复盘',
      reminderTime: HabitReminderPreset.evening.value,
      goalId: autoGoal.id,
      progressWeight: 0.8,
    );

    final habits = await habitRepo.watchHabitsForToday().first;
    if (habits.isNotEmpty) {
      await habitRepo.toggleHabitCheckIn(habits.first, true);
    }

    await scheduleRepo.createSchedule(
      title: '产品评审会',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.afternoon,
      duration: ScheduleDurationOption.oneHour,
      reminder: ScheduleReminderOption.fifteen,
    );
    await scheduleRepo.createSchedule(
      title: '明天方案同步',
      day: QuickScheduleDay.tomorrow,
      slot: QuickScheduleSlot.morning,
      duration: ScheduleDurationOption.halfHour,
      reminder: ScheduleReminderOption.five,
    );
  }
}
