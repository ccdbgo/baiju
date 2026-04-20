import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/domain/app_support_draft.dart';
import 'package:baiju_app/features/settings/infrastructure/app_settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return AppSettingsRepository(database);
});

final appDisplaySettingsProvider =
    StreamProvider.autoDispose<AppDisplaySettings>((ref) {
      final repository = ref.watch(appSettingsRepositoryProvider);
      return repository.watchDisplaySettings();
    });

final appSettingsActionsProvider = Provider<AppSettingsActions>((ref) {
  final repository = ref.watch(appSettingsRepositoryProvider);
  return AppSettingsActions(repository);
});

final appSupportDraftProvider = StreamProvider.autoDispose<AppSupportDraft>((
  ref,
) {
  final repository = ref.watch(appSettingsRepositoryProvider);
  return repository.watchSupportDraft();
});

class AppSettingsActions {
  const AppSettingsActions(this._repository);

  final AppSettingsRepository _repository;

  Future<void> save(AppDisplaySettings settings) {
    return _repository.saveDisplaySettings(settings);
  }

  Future<void> saveSupportDraft(AppSupportDraft draft) {
    return _repository.saveSupportDraft(draft);
  }

  Future<void> clearSupportDraft() {
    return _repository.clearSupportDraft();
  }
}
