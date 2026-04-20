enum ScheduleFilter {
  all('全部'),
  today('今天'),
  upcoming('即将到来'),
  completed('已完成');

  const ScheduleFilter(this.label);

  final String label;
}

enum QuickScheduleDay {
  today(0, '今天'),
  tomorrow(1, '明天');

  const QuickScheduleDay(this.offsetDays, this.label);

  final int offsetDays;
  final String label;
}

enum QuickScheduleSlot {
  morning(9, '上午 09:00'),
  afternoon(14, '下午 14:00'),
  evening(19, '晚上 19:00');

  const QuickScheduleSlot(this.hour, this.label);

  final int hour;
  final String label;
}

enum ScheduleDurationOption {
  halfHour(30, '30 分钟'),
  oneHour(60, '1 小时'),
  ninetyMinutes(90, '90 分钟');

  const ScheduleDurationOption(this.minutes, this.label);

  final int minutes;
  final String label;
}

enum ScheduleReminderOption {
  none(null, '不提醒'),
  five(5, '提前 5 分钟'),
  fifteen(15, '提前 15 分钟'),
  thirty(30, '提前 30 分钟');

  const ScheduleReminderOption(this.minutes, this.label);

  final int? minutes;
  final String label;

  static ScheduleReminderOption fromMinutes(int? minutes) {
    return ScheduleReminderOption.values.firstWhere(
      (option) => option.minutes == minutes,
      orElse: () => ScheduleReminderOption.none,
    );
  }
}

enum ScheduleRecurrenceKind { none, daily, weekdays, weekly, monthly, custom }

class ScheduleRecurrenceRule {
  const ScheduleRecurrenceRule._({
    required this.kind,
    required this.rule,
    required this.label,
  });

  final ScheduleRecurrenceKind kind;
  final String? rule;
  final String label;

  static const ScheduleRecurrenceRule none = ScheduleRecurrenceRule._(
    kind: ScheduleRecurrenceKind.none,
    rule: null,
    label: '不重复',
  );

  static const ScheduleRecurrenceRule daily = ScheduleRecurrenceRule._(
    kind: ScheduleRecurrenceKind.daily,
    rule: 'FREQ=DAILY',
    label: '每天',
  );

  static const ScheduleRecurrenceRule weekdays = ScheduleRecurrenceRule._(
    kind: ScheduleRecurrenceKind.weekdays,
    rule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
    label: '工作日',
  );

  static const ScheduleRecurrenceRule weekly = ScheduleRecurrenceRule._(
    kind: ScheduleRecurrenceKind.weekly,
    rule: 'FREQ=WEEKLY',
    label: '每周',
  );

  static const ScheduleRecurrenceRule monthly = ScheduleRecurrenceRule._(
    kind: ScheduleRecurrenceKind.monthly,
    rule: 'FREQ=MONTHLY',
    label: '每月',
  );

  static const List<ScheduleRecurrenceRule> presets =
      <ScheduleRecurrenceRule>[none, daily, weekdays, weekly, monthly];

  static ScheduleRecurrenceRule fromRule(String? recurrenceRule) {
    final normalized = normalizeRule(recurrenceRule);
    if (normalized == null) {
      return none;
    }

    for (final option in presets.where((item) => item.rule != null)) {
      if (option.rule == normalized) {
        return option;
      }
    }

    return ScheduleRecurrenceRule._(
      kind: ScheduleRecurrenceKind.custom,
      rule: normalized,
      label: '自定义规则',
    );
  }

  static String? normalizeRule(String? recurrenceRule) {
    final trimmed = recurrenceRule?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class ScheduleSummary {
  const ScheduleSummary({
    required this.total,
    required this.today,
    required this.upcoming,
    required this.completed,
  });

  final int total;
  final int today;
  final int upcoming;
  final int completed;
}
