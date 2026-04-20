import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/infrastructure/todo_repository.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TodoRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TodoRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('createTodo writes todo, sync queue and timeline event', () async {
    await repository.createTodo(
      title: '整理会议纪要',
      priority: TodoPriority.high,
      dueToday: true,
    );

    final todos = await database.select(database.todosTable).get();
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(todos, hasLength(1));
    expect(todos.single.title, '整理会议纪要');
    expect(todos.single.priority, 'high');
    expect(todos.single.status, 'open');
    expect(syncQueue, hasLength(1));
    expect(syncQueue.single.operation, 'create');
    expect(timelineEvents, hasLength(1));
    expect(timelineEvents.single.eventAction, 'created');
  });

  test('toggleTodoCompletion updates status and appends tracking records',
      () async {
    await repository.createTodo(
      title: '完成周报',
      priority: TodoPriority.medium,
      dueToday: false,
    );

    final todo = (await database.select(database.todosTable).get()).single;

    await repository.toggleTodoCompletion(todo, true);

    final updatedTodo = (await database.select(database.todosTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(updatedTodo.status, 'completed');
    expect(updatedTodo.completedAt, isNotNull);
    expect(updatedTodo.localVersion, 2);
    expect(syncQueue, hasLength(2));
    expect(syncQueue.last.operation, 'update');
    expect(timelineEvents, hasLength(2));
    expect(
      timelineEvents.any((event) => event.eventAction == 'completed'),
      isTrue,
    );
  });

  test('watchTodos filters active and completed lists correctly', () async {
    await repository.createTodo(
      title: '今日复盘',
      priority: TodoPriority.low,
      dueToday: false,
    );
    await repository.createTodo(
      title: '提交报销',
      priority: TodoPriority.high,
      dueToday: true,
    );

    final todos = await database.select(database.todosTable).get();
    final completedTodo = todos.firstWhere((todo) => todo.title == '今日复盘');

    await repository.toggleTodoCompletion(completedTodo, true);

    final activeTodos = await repository.watchTodos(TodoFilter.active).first;
    final completedTodos =
        await repository.watchTodos(TodoFilter.completed).first;
    final todayTodos = await repository.watchTodos(TodoFilter.today).first;

    expect(activeTodos, hasLength(1));
    expect(activeTodos.single.title, '提交报销');
    expect(completedTodos, hasLength(1));
    expect(completedTodos.single.title, '今日复盘');
    expect(todayTodos, hasLength(1));
    expect(todayTodos.single.title, '提交报销');
  });

  test('markTodoScheduled writes convertedScheduleId and timeline event',
      () async {
    await repository.createTodo(
      title: '预留发布窗口',
      priority: TodoPriority.medium,
      dueToday: false,
    );

    final todo = (await database.select(database.todosTable).get()).single;
    final scheduleStart = DateTime.now().toUtc().add(const Duration(hours: 2));

    await repository.markTodoScheduled(
      todo: todo,
      scheduleId: 'schedule-001',
      startAt: scheduleStart,
    );

    final updatedTodo = (await database.select(database.todosTable).get()).single;
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(updatedTodo.convertedScheduleId, 'schedule-001');
    expect(updatedTodo.plannedAt, isNotNull);
    expect(updatedTodo.plannedAt!.difference(scheduleStart).inSeconds.abs(), 0);
    expect(
      timelineEvents.any((event) => event.eventAction == 'scheduled'),
      isTrue,
    );
  });

  test('archiveTodo and deleteTodo write lifecycle records', () async {
    await repository.createTodo(
      title: '归档后删除',
      priority: TodoPriority.low,
      dueToday: false,
    );

    final created = (await database.select(database.todosTable).get()).single;
    await repository.archiveTodo(created);

    final archived = (await database.select(database.todosTable).get()).single;
    expect(archived.status, 'archived');

    await repository.deleteTodo(archived);

    final deleted = (await database.select(database.todosTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(deleted.deletedAt, isNotNull);
    expect(syncQueue.last.operation, 'delete');
    expect(timelineEvents.any((event) => event.eventAction == 'archived'), isTrue);
    expect(timelineEvents.any((event) => event.eventAction == 'deleted'), isTrue);
  });

  test('watchTodos is isolated by current user workspace', () async {
    final workRepository = TodoRepository(
      database,
      workspace: const UserWorkspace(userId: 'user-work', deviceId: 'device-1'),
    );
    final personalRepository = TodoRepository(
      database,
      workspace: const UserWorkspace(userId: 'user-life', deviceId: 'device-2'),
    );

    await workRepository.createTodo(
      title: '工作待办',
      priority: TodoPriority.high,
      dueToday: true,
    );
    await personalRepository.createTodo(
      title: '生活待办',
      priority: TodoPriority.low,
      dueToday: false,
    );

    final workTodos = await workRepository.watchTodos(TodoFilter.all).first;
    final personalTodos =
        await personalRepository.watchTodos(TodoFilter.all).first;

    expect(workTodos, hasLength(1));
    expect(workTodos.single.title, '工作待办');
    expect(personalTodos, hasLength(1));
    expect(personalTodos.single.title, '生活待办');
  });

  test('rolloverOverdueTodosToToday only updates overdue open todos', () async {
    final repository = TodoRepository(
      database,
      workspace: const UserWorkspace(userId: 'user-rollover', deviceId: 'device-1'),
    );

    await repository.createTodo(
      title: '过期待办',
      priority: TodoPriority.medium,
      dueToday: false,
    );

    final original = (await database.select(database.todosTable).get()).single;
    final pastDue = DateTime.now()
        .subtract(const Duration(days: 1))
        .toUtc();
    await (database.update(database.todosTable)
          ..where((tbl) => tbl.id.equals(original.id)))
        .write(
      TodosTableCompanion(
        dueAt: Value(pastDue),
        plannedAt: Value(pastDue),
      ),
    );

    final updatedCount = await repository.rolloverOverdueTodosToToday();
    final updated = (await database.select(database.todosTable).get()).single;

    expect(updatedCount, 1);
    expect(updated.dueAt, isNotNull);
    expect(updated.dueAt!.isAfter(DateTime.now().toUtc().subtract(const Duration(hours: 1))), isTrue);
  });

  test('todo subtask supports CRUD and watch stream', () async {
    await repository.createTodo(
      title: '拆解发布计划',
      priority: TodoPriority.high,
      dueToday: false,
    );
    final todo = (await database.select(database.todosTable).get()).single;

    await repository.createTodoSubtask(todoId: todo.id, title: '准备发布说明');
    await repository.createTodoSubtask(todoId: todo.id, title: '通知测试同学');

    final created = await repository.watchTodoSubtasks(todo.id).first;
    expect(created, hasLength(2));
    expect(created.first.sortOrder, 0);
    expect(created.last.sortOrder, 1);
    expect(created.first.isCompleted, isFalse);

    await repository.toggleTodoSubtaskCompletion(created.first, true);
    final afterToggle = await repository.watchTodoSubtasks(todo.id).first;
    expect(afterToggle.first.isCompleted, isTrue);
    expect(afterToggle.first.localVersion, 2);

    await repository.deleteTodoSubtask(afterToggle.last);
    final afterDelete = await repository.watchTodoSubtasks(todo.id).first;
    expect(afterDelete, hasLength(1));
    expect(afterDelete.single.title, '准备发布说明');

    final persisted = await (database.select(database.todoSubtasksTable)
          ..where((tbl) => tbl.todoId.equals(todo.id)))
        .get();
    expect(persisted, hasLength(2));
    expect(
      persisted.firstWhere((subtask) => subtask.title == '通知测试同学').deletedAt,
      isNotNull,
    );
  });

  test('todo subtask watch is isolated by current user workspace', () async {
    final workRepository = TodoRepository(
      database,
      workspace: const UserWorkspace(userId: 'user-work', deviceId: 'device-1'),
    );
    final personalRepository = TodoRepository(
      database,
      workspace: const UserWorkspace(userId: 'user-life', deviceId: 'device-2'),
    );

    await workRepository.createTodo(
      title: '工作待办',
      priority: TodoPriority.medium,
      dueToday: false,
    );
    await personalRepository.createTodo(
      title: '生活待办',
      priority: TodoPriority.low,
      dueToday: false,
    );

    final workTodo = (await workRepository.watchTodos(TodoFilter.all).first).single;
    final personalTodo =
        (await personalRepository.watchTodos(TodoFilter.all).first).single;

    await workRepository.createTodoSubtask(
      todoId: workTodo.id,
      title: '工作子任务',
    );
    await personalRepository.createTodoSubtask(
      todoId: personalTodo.id,
      title: '生活子任务',
    );

    final workSubtasks = await workRepository.watchTodoSubtasks(workTodo.id).first;
    final personalSubtasks =
        await personalRepository.watchTodoSubtasks(personalTodo.id).first;

    expect(workSubtasks, hasLength(1));
    expect(workSubtasks.single.title, '工作子任务');
    expect(personalSubtasks, hasLength(1));
    expect(personalSubtasks.single.title, '生活子任务');
  });

  test('createTodoFromSchedule links schedule id and returns todo id', () async {
    final now = DateTime.now().toUtc();
    await database.into(database.schedulesTable).insert(
          SchedulesTableCompanion.insert(
            id: 'schedule-linked-1',
            userId: 'local',
            title: 'linked schedule',
            description: const Value('schedule description'),
            startAt: now.add(const Duration(hours: 2)),
            endAt: now.add(const Duration(hours: 3)),
            location: const Value('Room 401'),
            category: const Value('work'),
            createdAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('synced'),
            localVersion: const Value(1),
            deviceId: const Value('local'),
          ),
        );
    final schedule = (await database.select(database.schedulesTable).get()).single;

    final todoId = await repository.createTodoFromSchedule(
      schedule: schedule,
      priority: TodoPriority.high,
    );

    final todo = (await (database.select(database.todosTable)
          ..where((tbl) => tbl.id.equals(todoId)))
        .getSingle());
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(todo.convertedScheduleId, schedule.id);
    expect(todo.priority, TodoPriority.high.value);
    expect(todo.description, contains('schedule description'));
    expect(todo.description, contains('Location: Room 401'));
    expect(todo.description, contains('Category: work'));

    final createPayload =
        jsonDecode(syncQueue.last.payloadJson) as Map<String, dynamic>;
    expect(createPayload['source_schedule_id'], schedule.id);
    expect(createPayload['converted_schedule_id'], schedule.id);
    expect(
      timelineEvents.any((event) => event.eventAction == 'created_from_schedule'),
      isTrue,
    );
  });
}
