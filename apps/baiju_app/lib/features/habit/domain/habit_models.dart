import 'package:baiju_app/core/database/app_database.dart';

enum HabitReminderPreset {
  none(null, '不提醒'),
  morning('08:00', '08:00'),
  evening('20:00', '20:00'),
  custom(null, '自定义');

  const HabitReminderPreset(this.value, this.label);

  final String? value;
  final String label;

  static HabitReminderPreset fromReminderTime(String? reminderTime) {
    if (reminderTime == null || reminderTime.isEmpty) {
      return HabitReminderPreset.none;
    }
    if (reminderTime == HabitReminderPreset.morning.value) {
      return HabitReminderPreset.morning;
    }
    if (reminderTime == HabitReminderPreset.evening.value) {
      return HabitReminderPreset.evening;
    }
    return HabitReminderPreset.custom;
  }
}

class HabitSummary {
  const HabitSummary({
    required this.total,
    required this.active,
    required this.checkedToday,
  });

  final int total;
  final int active;
  final int checkedToday;
}

class HabitTodayItem {
  const HabitTodayItem({
    required this.habit,
    required this.checkedToday,
    required this.record,
  });

  final HabitsTableData habit;
  final bool checkedToday;
  final HabitRecordsTableData? record;
}

enum HabitRecordStatus {
  done('done', '已完成'),
  skipped('skipped', '已跳过'),
  none('none', '未记录');

  const HabitRecordStatus(this.value, this.label);

  final String value;
  final String label;

  static HabitRecordStatus fromValue(String? value) {
    return switch (value) {
      'done' => HabitRecordStatus.done,
      'skipped' => HabitRecordStatus.skipped,
      _ => HabitRecordStatus.none,
    };
  }
}

enum HabitStatsWindow {
  last7Days(7, '近7天'),
  last30Days(30, '近30天');

  const HabitStatsWindow(this.days, this.label);

  final int days;
  final String label;
}

class HabitCompletionStats {
  const HabitCompletionStats({
    required this.window,
    required this.totalDays,
    required this.doneDays,
    required this.skippedDays,
    required this.missingDays,
    required this.currentStreak,
    required this.longestStreak,
  });

  final HabitStatsWindow window;
  final int totalDays;
  final int doneDays;
  final int skippedDays;
  final int missingDays;
  final int currentStreak;
  final int longestStreak;

  double get completionRate =>
      totalDays == 0 ? 0 : doneDays / totalDays;

  String get completionRateLabel =>
      '${(completionRate * 100).toStringAsFixed(0)}%';
}

class HabitRecordDayState {
  const HabitRecordDayState({
    required this.date,
    required this.status,
  });

  final DateTime date;
  final HabitRecordStatus status;
}

class HabitDetailInsights {
  const HabitDetailInsights({
    required this.stats7Days,
    required this.stats30Days,
    required this.recentRecords,
  });

  final HabitCompletionStats stats7Days;
  final HabitCompletionStats stats30Days;
  final List<HabitRecordDayState> recentRecords;
}
