import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/app_notification_service.dart';
import 'package:baiju_app/core/notifications/reminder_scheduler.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  if (kIsWeb) return const NoopReminderScheduler();
  return AppNotificationService.instance;
});

final reminderSyncControllerProvider = Provider<ReminderSyncController>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final scheduler = ref.watch(reminderSchedulerProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return ReminderSyncController(database, scheduler, workspace.userId);
});

final pendingReminderCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final scheduler = ref.watch(reminderSchedulerProvider);
  final requests = await scheduler.pendingReminderRequests();
  return requests.length;
});

/// Streams the count of items whose reminder time has already passed
/// but are still active (in-app notification badge).
final dueReminderCountProvider = StreamProvider.autoDispose<int>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);

  final now = DateTime.now().toUtc();
  final reminderCutoff = now.subtract(const Duration(minutes: 30));

  // Schedules: reminder already due = startAt - reminderMinutesBefore <= now AND status == planned
  final scheduleStream = (database.select(database.schedulesTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.status.equals('planned') &
              tbl.reminderMinutesBefore.isNotNull() &
              tbl.startAt.isBiggerOrEqualValue(now),
        ))
      .watch();

  // Todos: dueAt - 30min <= now AND dueAt > now (reminder window)
  final todoStream = (database.select(database.todosTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.status.isNotValue('completed') &
              tbl.status.isNotValue('archived') &
              tbl.dueAt.isNotNull() &
              tbl.dueAt.isBiggerOrEqualValue(now) &
              tbl.dueAt.isSmallerOrEqualValue(now.add(const Duration(hours: 24))),
        ))
      .watch();

  return scheduleStream.asyncMap((schedules) async {
    final todos = await todoStream.first;

    int count = 0;

    // Count schedules whose reminder time is in [reminderCutoff, now]
    for (final s in schedules) {
      if (s.reminderMinutesBefore == null) continue;
      final reminderAt = s.startAt.subtract(Duration(minutes: s.reminderMinutesBefore!));
      if (!reminderAt.isAfter(now) && reminderAt.isAfter(reminderCutoff)) {
        count++;
      }
    }

    // Count todos whose dueAt - 30min is in [reminderCutoff, now]
    for (final t in todos) {
      final dueAt = t.dueAt;
      if (dueAt == null) continue;
      final reminderAt = dueAt.subtract(const Duration(minutes: 30));
      if (!reminderAt.isAfter(now) && reminderAt.isAfter(reminderCutoff)) {
        count++;
      }
    }

    return count;
  });
});

class ReminderSyncController {
  const ReminderSyncController(this._database, this._scheduler, this._userId);

  final AppDatabase _database;
  final ReminderScheduler _scheduler;
  final String _userId;

  Future<void> syncAll() async {
    final schedules = await (_database.select(_database.schedulesTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_userId) &
                tbl.status.equals('planned'),
          ))
        .get();
    final habits = await (_database.select(_database.habitsTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_userId) &
                tbl.status.equals('active'),
          ))
        .get();
    final todos = await (_database.select(_database.todosTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_userId) &
                tbl.status.isNotValue('completed') &
                tbl.status.isNotValue('archived') &
                tbl.dueAt.isNotNull(),
          ))
        .get();

    await _scheduler.syncAllReminders(
      schedules: schedules,
      habits: habits,
      todos: todos,
    );
  }

  Future<void> clearAll() {
    return _scheduler.cancelAllManagedReminders();
  }
}
