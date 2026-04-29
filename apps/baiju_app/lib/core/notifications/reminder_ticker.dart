import 'dart:async';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/app_notification_service.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Polls every minute and fires an immediate notification for any reminder
/// whose scheduled time falls within the current minute window.
/// This is needed on Windows (non-MSIX) because ScheduledToastNotification
/// requires a running COM server to activate — unreliable for plain .exe apps.
class ReminderTicker {
  ReminderTicker(this._database, this._userId);

  final AppDatabase _database;
  final String _userId;

  Timer? _timer;

  /// Tracks which entity IDs have already been notified to avoid duplicates.
  final Set<String> _notified = {};

  void start() {
    _timer?.cancel();
    // Fire immediately, then every 60 seconds.
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (kIsWeb) return;
    final now = DateTime.now().toUtc();
    // Window: [now - 60s, now + 5s] — catches reminders due in this tick
    final windowStart = now.subtract(const Duration(seconds: 60));
    final windowEnd = now.add(const Duration(seconds: 5));

    await _checkSchedules(windowStart, windowEnd, now);
    await _checkTodos(windowStart, windowEnd);
  }

  Future<void> _checkSchedules(
    DateTime windowStart,
    DateTime windowEnd,
    DateTime now,
  ) async {
    final schedules = await (_database.select(_database.schedulesTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_userId) &
                tbl.status.equals('planned') &
                tbl.reminderMinutesBefore.isNotNull() &
                tbl.startAt.isBiggerOrEqualValue(now),
          ))
        .get();

    for (final s in schedules) {
      if (s.reminderMinutesBefore == null) continue;
      final reminderAt =
          s.startAt.subtract(Duration(minutes: s.reminderMinutesBefore!));
      if (reminderAt.isAfter(windowStart) &&
          reminderAt.isBefore(windowEnd) &&
          !_notified.contains('schedule:${s.id}')) {
        _notified.add('schedule:${s.id}');
        await AppNotificationService.instance.showImmediate(
          id: 'schedule:${s.id}',
          title: '日程提醒',
          body: s.title,
          payload: 'schedule:${s.id}',
        );
      }
    }
  }

  Future<void> _checkTodos(DateTime windowStart, DateTime windowEnd) async {
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

    for (final t in todos) {
      final dueAt = t.dueAt;
      if (dueAt == null) continue;
      final reminderAt = dueAt.subtract(const Duration(minutes: 30));
      if (reminderAt.isAfter(windowStart) &&
          reminderAt.isBefore(windowEnd) &&
          !_notified.contains('todo:${t.id}')) {
        _notified.add('todo:${t.id}');
        await AppNotificationService.instance.showImmediate(
          id: 'todo:${t.id}',
          title: '待办提醒',
          body: t.title,
          payload: 'todo:${t.id}',
        );
      }
    }
  }
}

final reminderTickerProvider = Provider<ReminderTicker>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return ReminderTicker(database, workspace.userId);
});
