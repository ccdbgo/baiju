import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/domain/app_support_draft.dart';
import 'package:drift/drift.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._database);

  final AppDatabase _database;

  static const String _showTodayHeroKey = 'show_today_hero';
  static const String _showActiveTodoPreviewKey = 'show_active_todo_preview';
  static const String _showUpcomingAnniversariesKey =
      'show_upcoming_anniversaries';
  static const String _showRecentNotesKey = 'show_recent_notes';
  static const String _showWeatherKey = 'show_weather';
  static const String _supportCategoryKey = 'support_category';
  static const String _supportContactKey = 'support_contact';
  static const String _supportMessageKey = 'support_message';

  Stream<AppDisplaySettings> watchDisplaySettings() {
    return (_database.select(_database.appSettingsTable)..where(
          (tbl) => tbl.key.isIn(<String>[
            _showTodayHeroKey,
            _showActiveTodoPreviewKey,
            _showUpcomingAnniversariesKey,
            _showRecentNotesKey,
            _showWeatherKey,
          ]),
        ))
        .watch()
        .map((rows) {
          final values = <String, String?>{
            for (final row in rows) row.key: row.value,
          };
          return AppDisplaySettings(
            showTodayHero: _parseBool(values[_showTodayHeroKey], true),
            showActiveTodoPreview: _parseBool(
              values[_showActiveTodoPreviewKey],
              true,
            ),
            showUpcomingAnniversaries: _parseBool(
              values[_showUpcomingAnniversariesKey],
              true,
            ),
            showRecentNotes: _parseBool(values[_showRecentNotesKey], true),
            showWeather: _parseBool(values[_showWeatherKey], true),
          );
        });
  }

  Future<void> saveDisplaySettings(AppDisplaySettings settings) async {
    final now = DateTime.now().toUtc();
    await _saveBool(_showTodayHeroKey, settings.showTodayHero, now);
    await _saveBool(
      _showActiveTodoPreviewKey,
      settings.showActiveTodoPreview,
      now,
    );
    await _saveBool(
      _showUpcomingAnniversariesKey,
      settings.showUpcomingAnniversaries,
      now,
    );
    await _saveBool(_showRecentNotesKey, settings.showRecentNotes, now);
    await _saveBool(_showWeatherKey, settings.showWeather, now);
  }

  Stream<AppSupportDraft> watchSupportDraft() {
    return (_database.select(_database.appSettingsTable)..where(
          (tbl) => tbl.key.isIn(<String>[
            _supportCategoryKey,
            _supportContactKey,
            _supportMessageKey,
          ]),
        ))
        .watch()
        .map((rows) {
          final values = <String, String?>{
            for (final row in rows) row.key: row.value,
          };
          return AppSupportDraft(
            category: SupportCategory.fromValue(values[_supportCategoryKey]),
            contact: values[_supportContactKey] ?? '',
            message: values[_supportMessageKey] ?? '',
          );
        });
  }

  Future<void> saveSupportDraft(AppSupportDraft draft) async {
    final now = DateTime.now().toUtc();
    await _saveString(_supportCategoryKey, draft.category.value, now);
    await _saveString(_supportContactKey, draft.contact.trim(), now);
    await _saveString(_supportMessageKey, draft.message.trim(), now);
  }

  Future<void> clearSupportDraft() async {
    final now = DateTime.now().toUtc();
    await _saveString(_supportCategoryKey, SupportCategory.feedback.value, now);
    await _saveString(_supportContactKey, '', now);
    await _saveString(_supportMessageKey, '', now);
  }

  Future<void> _saveBool(String key, bool value, DateTime now) {
    return _saveString(key, value.toString(), now);
  }

  Future<void> _saveString(String key, String value, DateTime now) {
    return _database
        .into(_database.appSettingsTable)
        .insert(
          AppSettingsTableCompanion.insert(
            key: key,
            value: Value(value),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  bool _parseBool(String? value, bool fallback) {
    if (value == null) {
      return fallback;
    }
    return value.toLowerCase() == 'true';
  }
}
