import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';

class UserPreferences {
  const UserPreferences({
    this.autoRolloverTodosToToday = false,
    this.defaultScheduleReminderMinutes = 15,
    this.autoSyncOnLaunch = true,
  });

  final bool autoRolloverTodosToToday;
  final int? defaultScheduleReminderMinutes;
  final bool autoSyncOnLaunch;

  ScheduleReminderOption get defaultScheduleReminderOption {
    return ScheduleReminderOption.fromMinutes(defaultScheduleReminderMinutes);
  }

  UserPreferences copyWith({
    bool? autoRolloverTodosToToday,
    int? defaultScheduleReminderMinutes,
    bool? autoSyncOnLaunch,
    bool clearDefaultScheduleReminder = false,
  }) {
    return UserPreferences(
      autoRolloverTodosToToday:
          autoRolloverTodosToToday ?? this.autoRolloverTodosToToday,
      defaultScheduleReminderMinutes: clearDefaultScheduleReminder
          ? null
          : defaultScheduleReminderMinutes ?? this.defaultScheduleReminderMinutes,
      autoSyncOnLaunch: autoSyncOnLaunch ?? this.autoSyncOnLaunch,
    );
  }
}
