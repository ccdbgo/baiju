enum TodoFilter {
  all('全部'),
  active('进行中'),
  today('今天'),
  completed('已完成');

  const TodoFilter(this.label);

  final String label;
}

enum TodoPriority {
  urgentImportant('urgent_important', '重要紧急'),
  notUrgentImportant('not_urgent_important', '重要不紧急'),
  urgentNotImportant('urgent_not_important', '不重要紧急'),
  notUrgentNotImportant('not_urgent_not_important', '不重要不紧急');

  const TodoPriority(this.value, this.label);

  final String value;
  final String label;

  static TodoPriority fromValue(String value) {
    return TodoPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => TodoPriority.notUrgentImportant,
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
