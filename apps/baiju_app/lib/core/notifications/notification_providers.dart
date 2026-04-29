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
