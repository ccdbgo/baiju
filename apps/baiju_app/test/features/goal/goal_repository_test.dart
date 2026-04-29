import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/goal_dao.dart';
import 'package:baiju_app/core/database/daos/habit_dao.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/infrastructure/goal_repository.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/infrastructure/habit_repository.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/infrastructure/todo_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late GoalRepository repository;
  late TodoRepository todoRepository;
  late HabitRepository habitRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = GoalRepository(database, GoalDao(database));
    todoRepository = TodoRepository(database);
    habitRepository = HabitRepository(database, HabitDao(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('createGoal writes goal and timeline event', () async {
    await repository.createGoal(
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

    final goals = await database.select(database.goalsTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(goals, hasLength(1));
    expect(goals.single.title, '完成四月专题学习');
    expect(goals.single.goalType, 'monthly');
    expect(goals.single.progressMode, 'manual');
    expect(goals.single.progressTarget, 10);
    expect(timelineEvents, hasLength(1));
    expect(timelineEvents.single.eventAction, 'created');
  });

  test('updateGoal updates fields and appends tracking event', () async {
    await repository.createGoal(
      title: '建立晨间习惯',
      goalType: GoalType.stage,
      progressMode: GoalProgressMode.manual,
      todoWeight: 0.7,
      habitWeight: 0.3,
      todoUnitWeight: 1.0,
      habitUnitWeight: 0.5,
      progressTarget: 30,
      unit: '天',
    );

    final goal = (await database.select(database.goalsTable).get()).single;

    await repository.updateGoal(
      goal: goal,
      title: '建立晚间习惯',
      goalType: GoalType.stage,
      progressMode: GoalProgressMode.todos,
      todoWeight: 0.7,
      habitWeight: 0.3,
      todoUnitWeight: 1.0,
      habitUnitWeight: 0.5,
      status: GoalStatus.active,
      progressValue: 12,
      progressTarget: 30,
      unit: '天',
    );

    final updated = (await database.select(database.goalsTable).get()).single;
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(updated.title, '建立晚间习惯');
    expect(updated.progressMode, 'todos');
    expect(updated.progressValue, 12);
    expect(updated.unit, '天');
    expect(
      timelineEvents.any((event) => event.eventAction == 'updated'),
      isTrue,
    );
  });

  test('goal progress auto updates from linked todos and habits', () async {
    await repository.createGoal(
      title: '建立自律系统',
      goalType: GoalType.stage,
      progressMode: GoalProgressMode.mixed,
      todoWeight: 0.7,
      habitWeight: 0.3,
      todoUnitWeight: 1.0,
      habitUnitWeight: 0.5,
      progressTarget: null,
      unit: null,
    );
    final goal = (await database.select(database.goalsTable).get()).single;

    await todoRepository.createTodo(
      title: '整理晨间计划',
      priority: TodoPriority.urgentImportant,
      dueToday: true,
      goalId: goal.id,
    );
    await habitRepository.createHabit(
      name: '晚间复盘',
      reminderTime: HabitReminderPreset.evening.value,
      goalId: goal.id,
    );

    final todo = (await database.select(database.todosTable).get()).single;
    final habitItem = (await habitRepository.watchHabitsForToday().first).single;

    await todoRepository.toggleTodoCompletion(todo, true);
    await habitRepository.toggleHabitCheckIn(habitItem, true);

    final overview = (await repository.watchGoalOverviews().firstWhere(
      (items) =>
          items.isNotEmpty &&
          items.single.completedTodoCount == 1 &&
          items.single.checkedHabitCount == 1,
    ))
        .single;

    expect(overview.linkedTodoCount, 1);
    expect(overview.linkedHabitCount, 1);
    expect(overview.completedTodoCount, 1);
    expect(overview.checkedHabitCount, 1);
    expect(overview.usesAutoProgress, isTrue);
    expect(overview.progressRatio, 1);
  });

  test('goal lifecycle actions update status and deletion marker', () async {
    await repository.createGoal(
      title: '生命周期目标',
      goalType: GoalType.stage,
      progressMode: GoalProgressMode.manual,
      todoWeight: 0.7,
      habitWeight: 0.3,
      todoUnitWeight: 1.0,
      habitUnitWeight: 0.5,
      progressTarget: 1,
      unit: '项',
    );

    final created = (await database.select(database.goalsTable).get()).single;
    await repository.setGoalPaused(created, true);

    final paused = (await database.select(database.goalsTable).get()).single;
    expect(paused.status, GoalStatus.paused.value);

    await repository.archiveGoal(paused);

    final archived = (await database.select(database.goalsTable).get()).single;
    expect(archived.status, GoalStatus.abandoned.value);

    await repository.deleteGoal(archived);

    final deleted = (await database.select(database.goalsTable).get()).single;
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(deleted.deletedAt, isNotNull);
    expect(timelineEvents.any((event) => event.eventAction == 'paused'), isTrue);
    expect(timelineEvents.any((event) => event.eventAction == 'archived'), isTrue);
    expect(timelineEvents.any((event) => event.eventAction == 'deleted'), isTrue);
  });
}
