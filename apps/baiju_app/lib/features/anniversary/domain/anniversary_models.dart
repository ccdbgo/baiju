enum AnniversaryReminderOption {
  none(null, '不提醒'),
  one(1, '提前 1 天'),
  three(3, '提前 3 天'),
  seven(7, '提前 7 天');

  const AnniversaryReminderOption(this.days, this.label);

  final int? days;
  final String label;

  static AnniversaryReminderOption fromDays(int? days) {
    return AnniversaryReminderOption.values.firstWhere(
      (option) => option.days == days,
      orElse: () => AnniversaryReminderOption.none,
    );
  }
}

class AnniversarySummary {
  const AnniversarySummary({
    required this.total,
    required this.upcoming30Days,
    required this.withReminder,
  });

  final int total;
  final int upcoming30Days;
  final int withReminder;
}
