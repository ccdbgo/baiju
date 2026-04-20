import 'package:baiju_app/core/database/app_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class ReminderScheduler {
  Future<void> initialize();

  Future<void> syncScheduleReminder(SchedulesTableData schedule);

  Future<void> syncHabitReminder(HabitsTableData habit);

  Future<void> syncAllReminders({
    required Iterable<SchedulesTableData> schedules,
    required Iterable<HabitsTableData> habits,
  });

  Future<void> cancelScheduleReminder(String scheduleId);

  Future<void> cancelHabitReminder(String habitId);

  Future<void> cancelAllManagedReminders();

  Future<List<PendingNotificationRequest>> pendingReminderRequests();
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> syncScheduleReminder(SchedulesTableData schedule) async {}

  @override
  Future<void> syncHabitReminder(HabitsTableData habit) async {}

  @override
  Future<void> syncAllReminders({
    required Iterable<SchedulesTableData> schedules,
    required Iterable<HabitsTableData> habits,
  }) async {}

  @override
  Future<void> cancelScheduleReminder(String scheduleId) async {}

  @override
  Future<void> cancelHabitReminder(String habitId) async {}

  @override
  Future<void> cancelAllManagedReminders() async {}

  @override
  Future<List<PendingNotificationRequest>> pendingReminderRequests() async {
    return const <PendingNotificationRequest>[];
  }
}
