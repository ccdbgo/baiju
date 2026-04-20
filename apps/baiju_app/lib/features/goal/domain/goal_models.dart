import 'package:baiju_app/core/database/app_database.dart';

enum GoalType {
  yearly('yearly', '年度'),
  monthly('monthly', '月度'),
  stage('stage', '阶段');

  const GoalType(this.value, this.label);

  final String value;
  final String label;

  static GoalType fromValue(String value) {
    return GoalType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => GoalType.stage,
    );
  }
}

enum GoalStatus {
  active('active', '进行中'),
  completed('completed', '已完成'),
  paused('paused', '已暂停'),
  abandoned('abandoned', '已归档');

  const GoalStatus(this.value, this.label);

  final String value;
  final String label;

  static GoalStatus fromValue(String value) {
    return GoalStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => GoalStatus.active,
    );
  }
}

enum GoalProgressMode {
  manual('manual', '手动'),
  todos('todos', '仅待办'),
  habits('habits', '仅习惯'),
  mixed('mixed', '混合'),
  weightedMixed('weighted_mixed', '加权混合');

  const GoalProgressMode(this.value, this.label);

  final String value;
  final String label;

  static GoalProgressMode fromValue(String value) {
    return GoalProgressMode.values.firstWhere(
      (item) => item.value == value,
      orElse: () => GoalProgressMode.mixed,
    );
  }
}

class GoalOverview {
  const GoalOverview({
    required this.goal,
    required this.linkedTodoCount,
    required this.completedTodoCount,
    required this.linkedHabitCount,
    required this.checkedHabitCount,
    required this.totalHabitWeight,
    required this.checkedHabitWeight,
  });

  final GoalsTableData goal;
  final int linkedTodoCount;
  final int completedTodoCount;
  final int linkedHabitCount;
  final int checkedHabitCount;
  final double totalHabitWeight;
  final double checkedHabitWeight;

  GoalProgressMode get progressMode {
    return GoalProgressMode.fromValue(goal.progressMode);
  }

  bool get usesAutoProgress => progressMode != GoalProgressMode.manual;

  double get progressRatio {
    switch (progressMode) {
      case GoalProgressMode.manual:
        return _manualRatio;
      case GoalProgressMode.todos:
        return linkedTodoCount == 0
            ? _manualRatio
            : (completedTodoCount / linkedTodoCount).clamp(0, 1);
      case GoalProgressMode.habits:
        return linkedHabitCount == 0
            ? _manualRatio
            : (checkedHabitCount / linkedHabitCount).clamp(0, 1);
      case GoalProgressMode.mixed:
        final total = linkedTodoCount + linkedHabitCount;
        if (total == 0) {
          return _manualRatio;
        }
        return ((completedTodoCount + checkedHabitCount) / total).clamp(0, 1);
      case GoalProgressMode.weightedMixed:
        final todoTotal = linkedTodoCount * goal.todoUnitWeight;
        final todoDone = completedTodoCount * goal.todoUnitWeight;
        final habitTotal = totalHabitWeight * goal.habitUnitWeight;
        final habitDone = checkedHabitWeight * goal.habitUnitWeight;
        final totalWeight = todoTotal + habitTotal;
        if (totalWeight <= 0) {
          return _manualRatio;
        }
        return ((todoDone + habitDone) / totalWeight).clamp(0, 1);
    }
  }

  String get progressDescription {
    switch (progressMode) {
      case GoalProgressMode.manual:
        if (goal.progressTarget != null) {
          return '手动进度 ${goal.progressValue ?? 0}/${goal.progressTarget} ${goal.unit ?? ''}';
        }
        return '手动进度尚未配置';
      case GoalProgressMode.todos:
        return '待办进度 $completedTodoCount/$linkedTodoCount';
      case GoalProgressMode.habits:
        return '习惯进度 $checkedHabitCount/$linkedHabitCount';
      case GoalProgressMode.mixed:
        return '混合进度 ${completedTodoCount + checkedHabitCount}/${linkedTodoCount + linkedHabitCount}';
      case GoalProgressMode.weightedMixed:
        return '加权混合 待办权重 ${goal.todoUnitWeight.toStringAsFixed(1)} / 打卡权重 ${goal.habitUnitWeight.toStringAsFixed(1)}';
    }
  }

  double get _manualRatio {
    if (goal.progressTarget != null &&
        goal.progressTarget! > 0 &&
        goal.progressValue != null) {
      return (goal.progressValue! / goal.progressTarget!).clamp(0, 1);
    }
    return 0;
  }
}

class GoalSummary {
  const GoalSummary({
    required this.total,
    required this.active,
    required this.completed,
  });

  final int total;
  final int active;
  final int completed;
}

class GoalTrendPoint {
  const GoalTrendPoint({
    required this.date,
    required this.completedTodos,
    required this.checkedHabits,
  });

  final DateTime date;
  final int completedTodos;
  final int checkedHabits;
}
