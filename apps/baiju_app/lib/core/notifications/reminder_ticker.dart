import 'dart:async';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/app_notification_service.dart';
import 'package:baiju_app/core/notifications/native_notification_channel.dart';
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
    final windowStart = now.subtract(const Duration(seconds: 5));
    final windowEnd = now.add(const Duration(seconds: 5));

    await _checkSchedules(windowStart, windowEnd, now);
    await _checkTodos(windowStart, windowEnd);
  }

  Future<void> _notify(String key, String title, String body) async {
    if (_notified.contains(key)) return;
    _notified.add(key);
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
}

final reminderTickerProvider = Provider<ReminderTicker>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return ReminderTicker(database, workspace.userId);
});
