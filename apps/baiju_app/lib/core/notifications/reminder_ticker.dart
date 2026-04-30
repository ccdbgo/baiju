import 'dart:async';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/native_notification_channel.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Polls every 5 seconds and fires a native Windows balloon notification
/// for any reminder whose scheduled time falls within the current window.
/// Uses our own C++ plugin via MethodChannel — no third-party libraries.
class ReminderTicker {
  ReminderTicker(this._database, this._userId);

  final AppDatabase _database;
  final String _userId;

  Timer? _timer;

  /// Tracks notified entity IDs to avoid duplicate notifications.
  final Set<String> _notified = {};

  void start() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (kIsWeb) return;
    final now = DateTime.now().toUtc();
    // Window: [now - 5s, now + 5s] — catches reminders due in this 5-second tick
    final windowStart = now.subtract(const Duration(seconds: 5));
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
      final key = 'schedule:${s.id}';
      if (reminderAt.isAfter(windowStart) &&
          reminderAt.isBefore(windowEnd) &&
          !_notified.contains(key)) {
        _notified.add(key);
        await NativeNotificationChannel.show(
          title: '日程提醒',
          body: s.title,
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
      final key = 'todo:${t.id}';
      if (reminderAt.isAfter(windowStart) &&
          reminderAt.isBefore(windowEnd) &&
          !_notified.contains(key)) {
        _notified.add(key);
        await NativeNotificationChannel.show(
          title: '待办提醒',
          body: t.title,
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
