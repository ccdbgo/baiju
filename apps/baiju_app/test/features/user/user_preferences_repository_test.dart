import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/infrastructure/user_preferences_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserPreferencesRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = UserPreferencesRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('preferences are stored per user key namespace', () async {
    const work = UserWorkspace(userId: 'user-work', deviceId: 'device-a');
    const life = UserWorkspace(userId: 'user-life', deviceId: 'device-b');

    await repository.updatePreferences(
      workspace: work,
      preferences: const UserPreferences(
        autoRolloverTodosToToday: true,
        defaultScheduleReminderMinutes: 30,
        autoSyncOnLaunch: false,
      ),
    );
    await repository.updatePreferences(
      workspace: life,
      preferences: const UserPreferences(
        autoRolloverTodosToToday: false,
        defaultScheduleReminderMinutes: 5,
        autoSyncOnLaunch: true,
      ),
    );

    final workPreferences = await repository.watchPreferences(work).first;
    final lifePreferences = await repository.watchPreferences(life).first;

    expect(workPreferences.autoRolloverTodosToToday, isTrue);
    expect(workPreferences.defaultScheduleReminderMinutes, 30);
    expect(workPreferences.autoSyncOnLaunch, isFalse);

    expect(lifePreferences.autoRolloverTodosToToday, isFalse);
    expect(lifePreferences.defaultScheduleReminderMinutes, 5);
    expect(lifePreferences.autoSyncOnLaunch, isTrue);
  });
}
