import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:drift/drift.dart';

class UserPreferencesRepository {
  UserPreferencesRepository(this._database);

  final AppDatabase _database;

  static const String _rolloverKey = 'todo_auto_rollover';
  static const String _scheduleReminderKey = 'default_schedule_reminder';
  static const String _autoSyncKey = 'auto_sync_on_launch';

  Stream<UserPreferences> watchPreferences(UserWorkspace workspace) {
    final keys = _keysFor(workspace.userId);
    return (_database.select(_database.appSettingsTable)
          ..where((tbl) => tbl.key.isIn(keys)))
        .watch()
        .map((rows) => _mapRows(workspace.userId, rows));
  }

  Future<void> updatePreferences({
    required UserWorkspace workspace,
    required UserPreferences preferences,
  }) async {
    final now = DateTime.now().toUtc();
    await _writeSetting(
      _scopedKey(workspace.userId, _rolloverKey),
      preferences.autoRolloverTodosToToday ? 'true' : 'false',
      now,
    );
    await _writeSetting(
      _scopedKey(workspace.userId, _scheduleReminderKey),
      preferences.defaultScheduleReminderMinutes?.toString(),
      now,
    );
    await _writeSetting(
      _scopedKey(workspace.userId, _autoSyncKey),
      preferences.autoSyncOnLaunch ? 'true' : 'false',
      now,
    );
  }

  List<String> _keysFor(String userId) {
    return <String>[
      _scopedKey(userId, _rolloverKey),
      _scopedKey(userId, _scheduleReminderKey),
      _scopedKey(userId, _autoSyncKey),
    ];
  }

  UserPreferences _mapRows(String userId, List<AppSettingsTableData> rows) {
    final byKey = <String, String?>{
      for (final row in rows) row.key: row.value,
    };
    final reminderKey = _scopedKey(userId, _scheduleReminderKey);

    final rollover =
        byKey[_scopedKey(userId, _rolloverKey)]?.toLowerCase() == 'true';
    final hasReminderSetting = byKey.containsKey(reminderKey);
    final scheduleReminder = hasReminderSetting
        ? int.tryParse(byKey[reminderKey] ?? '')
        : 15;
    final autoSyncValue = byKey[_scopedKey(userId, _autoSyncKey)];
    final autoSync = autoSyncValue == null || autoSyncValue == 'true';

    return UserPreferences(
      autoRolloverTodosToToday: rollover,
      defaultScheduleReminderMinutes:
          hasReminderSetting ? scheduleReminder : 15,
      autoSyncOnLaunch: autoSync,
    );
  }

  String _scopedKey(String userId, String key) => 'user::$userId::$key';

  Future<void> _writeSetting(String key, String? value, DateTime now) {
    return _database.into(_database.appSettingsTable).insert(
          AppSettingsTableCompanion.insert(
            key: key,
            value: Value(value),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
