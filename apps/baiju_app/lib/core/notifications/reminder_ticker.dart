import 'dart:async';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/app_notification_service.dart';
import 'package:baiju_app/core/notifications/native_notification_channel.dart';
import 'package:baiju_app/core/notifications/reminder_event.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Polls every 5 seconds and fires a notification for any reminder whose
/// scheduled time falls within the current window.
///
/// Platform dispatch:
///   Windows — Shell_NotifyIcon balloon via our own C++ MethodChannel plugin
///   Android/iOS/macOS — flutter_local_notifications show()
///   Web — skipped (no persistent background, browser handles its own push)
class ReminderTicker {
  ReminderTicker(this._database, this._userId);

  final AppDatabase _database;
  final String _userId;

  Timer? _timer;

  /// Tracks notified entity IDs to avoid duplicate notifications.
  final Set<String> _notified = {};

  /// Broadcasts in-app reminder events so the UI can show a persistent dialog.
  final StreamController<ReminderEvent> _eventController =
      StreamController<ReminderEvent>.broadcast();

  Stream<ReminderEvent> get events => _eventController.stream;

  void start() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _eventController.close();
  }

  Future<void> _tick() async {
    if (kIsWeb) return;
    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(const Duration(seconds: 5));
    final windowEnd = now.add(const Duration(seconds: 5));

    await _checkSchedules(windowStart, windowEnd, now);
    await _checkTodos(windowStart, windowEnd);
    await _checkHabits(windowStart, windowEnd);
  }

  Future<void> _notify(String key, String title, String body) async {
    if (_notified.contains(key)) return;
    _notified.add(key);
    // Broadcast in-app event so the UI can show a persistent dialog.
    _eventController.add(ReminderEvent(title: title, body: body));
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await NativeNotificationChannel.show(title: title, body: body);
    } else {
      await AppNotificationService.instance
          .showImmediate(id: key, title: title, body: body);
    }
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
      if (reminderAt.isAfter(windowStart) && reminderAt.isBefore(windowEnd)) {
        await _notify('schedule:${s.id}', '日程提醒', s.title);
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
      if (reminderAt.isAfter(windowStart) && reminderAt.isBefore(windowEnd)) {
        await _notify('todo:${t.id}', '待办提醒', t.title);
      }
    }
  }

  Future<void> _checkHabits(DateTime windowStart, DateTime windowEnd) async {
    final habits = await (_database.select(_database.habitsTable)
          ..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(_userId) &
                tbl.status.equals('active') &
                tbl.reminderTime.isNotNull(),
          ))
        .get();

    final nowLocal = DateTime.now();
    final todayStr =
        '${nowLocal.year.toString().padLeft(4, '0')}-'
        '${nowLocal.month.toString().padLeft(2, '0')}-'
        '${nowLocal.day.toString().padLeft(2, '0')}';

    for (final h in habits) {
      final reminderTime = h.reminderTime;
      if (reminderTime == null || reminderTime.isEmpty) continue;
      final parts = reminderTime.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final reminderLocal = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        hour,
        minute,
      );
      final reminderUtc = reminderLocal.toUtc();

      if (reminderUtc.isAfter(windowStart) &&
          reminderUtc.isBefore(windowEnd)) {
        await _notify('habit:${h.id}:$todayStr', '习惯提醒', h.name);
      }
    }
  }
}

final reminderTickerProvider = Provider<ReminderTicker>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return ReminderTicker(database, workspace.userId);
});
