enum TodoFilter {
  all('全部'),
  active('进行中'),
  today('今天'),
  completed('已完成');

  const TodoFilter(this.label);

  final String label;
}

enum TodoPriority {
  low('low', '低优先级'),
  medium('medium', '中优先级'),
  high('high', '高优先级');

  const TodoPriority(this.value, this.label);

  final String value;
  final String label;

  static TodoPriority fromValue(String value) {
    return TodoPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => TodoPriority.medium,
    );
  }
}

class TodoSummary {
  const TodoSummary({
    required this.total,
    required this.active,
    required this.today,
    required this.completed,
  });

  final int total;
  final int active;
  final int today;
  final int completed;
}
