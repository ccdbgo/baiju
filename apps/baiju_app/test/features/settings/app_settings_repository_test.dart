import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/domain/app_support_draft.dart';
import 'package:baiju_app/features/settings/infrastructure/app_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AppSettingsRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = AppSettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('watchDisplaySettings returns defaults when rows are absent', () async {
    final settings = await repository.watchDisplaySettings().first;

    expect(settings.showTodayHero, isTrue);
    expect(settings.showActiveTodoPreview, isTrue);
    expect(settings.showUpcomingAnniversaries, isTrue);
    expect(settings.showRecentNotes, isTrue);
  });

  test(
    'saveDisplaySettings persists booleans into app settings table',
    () async {
      await repository.saveDisplaySettings(
        const AppDisplaySettings(
          showTodayHero: false,
          showActiveTodoPreview: true,
          showUpcomingAnniversaries: false,
          showRecentNotes: false,
        ),
      );

      final settings = await repository.watchDisplaySettings().first;
      final rows = await database.select(database.appSettingsTable).get();

      expect(settings.showTodayHero, isFalse);
      expect(settings.showActiveTodoPreview, isTrue);
      expect(settings.showUpcomingAnniversaries, isFalse);
      expect(settings.showRecentNotes, isFalse);
      expect(rows.length, 4);
    },
  );

  test('support draft is persisted and restored', () async {
    await repository.saveSupportDraft(
      const AppSupportDraft(
        category: SupportCategory.bug,
        contact: 'tester@example.com',
        message: '打开时间线时白屏',
      ),
    );

    final draft = await repository.watchSupportDraft().first;

    expect(draft.category, SupportCategory.bug);
    expect(draft.contact, 'tester@example.com');
    expect(draft.message, '打开时间线时白屏');
  });
}
