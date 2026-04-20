import 'dart:async';

import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final todayCompletionRateProvider =
    StreamProvider.autoDispose<double>((ref) {
  final scheduleRepository = ref.watch(scheduleRepositoryProvider);
  final todoRepository = ref.watch(todoRepositoryProvider);
  final habitRepository = ref.watch(habitRepositoryProvider);

  final schedulesStream =
      scheduleRepository.watchSchedules(ScheduleFilter.today);
  final todosStream = todoRepository.watchTodos(TodoFilter.today);
  final habitsStream = habitRepository.watchHabitsForToday();

  return Stream<double>.multi((controller) {
    var totalCount = 0;
    var completedCount = 0;

    var schedules = 0;
    var schedulesCompleted = 0;
    var todos = 0;
    var todosCompleted = 0;
    var habits = 0;
    var habitsCompleted = 0;

    void emit() {
      totalCount = schedules + todos + habits;
      completedCount = schedulesCompleted + todosCompleted + habitsCompleted;
      final rate = totalCount == 0 ? 0.0 : completedCount / totalCount;
      controller.add(rate);
    }

    final subscriptions = <StreamSubscription<dynamic>>[
      schedulesStream.listen((items) {
        schedules = items.length;
        schedulesCompleted =
            items.where((item) => item.status == 'completed').length;
        emit();
      }),
      todosStream.listen((items) {
        todos = items.length;
        todosCompleted = items.where((item) => item.status == 'completed').length;
        emit();
      }),
      habitsStream.listen((items) {
        habits = items.length;
        habitsCompleted = items.where((item) => item.checkedToday).length;
        emit();
      }),
    ];

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
});
