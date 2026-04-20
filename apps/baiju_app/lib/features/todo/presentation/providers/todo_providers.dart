import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/infrastructure/schedule_repository.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/infrastructure/todo_repository.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return TodoRepository(database, workspace: workspace);
});

final selectedTodoFilterProvider =
    NotifierProvider<SelectedTodoFilterNotifier, TodoFilter>(
  SelectedTodoFilterNotifier.new,
);

final todoListProvider =
    StreamProvider.autoDispose<List<TodosTableData>>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  final filter = ref.watch(selectedTodoFilterProvider);
  return repository.watchTodos(filter);
});

final todoDetailProvider =
    StreamProvider.family.autoDispose<TodosTableData?, String>((ref, todoId) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.todosTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.id.equals(todoId),
        ))
      .watchSingleOrNull();
});

final todoSubtaskListProvider =
    StreamProvider.family.autoDispose<List<TodoSubtasksTableData>, String>((
      ref,
      todoId,
    ) {
      final repository = ref.watch(todoRepositoryProvider);
      return repository.watchTodoSubtasks(todoId);
    });

final todayTodoListProvider =
    StreamProvider.autoDispose<List<TodosTableData>>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return repository.watchTodos(TodoFilter.today);
});

final activeTodoPreviewProvider =
    StreamProvider.autoDispose<List<TodosTableData>>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return repository.watchTodos(TodoFilter.active).map(
        (todos) => todos.take(5).toList(),
      );
});

final todoSummaryProvider =
    StreamProvider.autoDispose<TodoSummary>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  return repository.watchTodos(TodoFilter.all).map((todos) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);

    var active = 0;
    var completed = 0;
    var today = 0;

    for (final todo in todos) {
      final isCompleted = todo.status == 'completed';
      if (isCompleted) {
        completed++;
      } else {
        active++;
      }

      final dueAt = todo.dueAt?.toLocal();
      if (!isCompleted &&
          dueAt != null &&
          !dueAt.isBefore(start) &&
          dueAt.isBefore(end)) {
        today++;
      }
    }

    return TodoSummary(
      total: todos.length,
      active: active,
      today: today,
      completed: completed,
    );
  });
});

final todoActionsProvider = Provider<TodoActions>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  final scheduleRepository = ref.watch(scheduleRepositoryProvider);
  return TodoActions(repository, scheduleRepository);
});

class TodoActions {
  const TodoActions(this._repository, this._scheduleRepository);

  final TodoRepository _repository;
  final ScheduleRepository _scheduleRepository;

  Future<void> createTodo({
    required String title,
    required TodoPriority priority,
    required bool dueToday,
    String? goalId,
  }) {
    return _repository.createTodo(
      title: title,
      priority: priority,
      dueToday: dueToday,
      goalId: goalId,
    );
  }

  Future<void> toggleTodoCompletion(
    TodosTableData todo,
    bool completed,
  ) {
    return _repository.toggleTodoCompletion(todo, completed);
  }

  Future<void> updateTodo({
    required TodosTableData todo,
    required String title,
    required TodoPriority priority,
    required DateTime? dueAt,
  }) {
    return _repository.updateTodo(
      todo: todo,
      title: title,
      priority: priority,
      dueAt: dueAt,
    );
  }

  Future<void> archiveTodo(TodosTableData todo) {
    return _repository.archiveTodo(todo);
  }

  Future<void> deleteTodo(TodosTableData todo) {
    return _repository.deleteTodo(todo);
  }

  Future<void> createTodoSubtask({
    required String todoId,
    required String title,
  }) {
    return _repository.createTodoSubtask(todoId: todoId, title: title);
  }

  Future<void> toggleTodoSubtaskCompletion(
    TodoSubtasksTableData subtask,
    bool completed,
  ) {
    return _repository.toggleTodoSubtaskCompletion(subtask, completed);
  }

  Future<void> deleteTodoSubtask(TodoSubtasksTableData subtask) {
    return _repository.deleteTodoSubtask(subtask);
  }

  Future<void> convertTodoToSchedule({
    required TodosTableData todo,
    required QuickScheduleDay day,
    required QuickScheduleSlot slot,
    required ScheduleDurationOption duration,
    required ScheduleReminderOption reminder,
  }) async {
    final schedule = await _scheduleRepository.createSchedule(
      title: todo.title,
      day: day,
      slot: slot,
      duration: duration,
      reminder: reminder,
      sourceTodoId: todo.id,
    );
    await _repository.markTodoScheduled(
      todo: todo,
      scheduleId: schedule.id,
      startAt: schedule.startAt,
    );
  }

  Future<String> createTodoFromSchedule({
    required SchedulesTableData schedule,
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueAt,
  }) {
    return _repository.createTodoFromSchedule(
      schedule: schedule,
      priority: priority,
      dueAt: dueAt,
    );
  }
}

class SelectedTodoFilterNotifier extends Notifier<TodoFilter> {
  @override
  TodoFilter build() {
    return TodoFilter.active;
  }

  void select(TodoFilter filter) {
    state = filter;
  }
}
