import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/infrastructure/user_preferences_repository.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userPreferencesRepositoryProvider =
    Provider<UserPreferencesRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return UserPreferencesRepository(database);
});

final userPreferencesProvider = StreamProvider.autoDispose<UserPreferences>((ref) {
  final repository = ref.watch(userPreferencesRepositoryProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return repository.watchPreferences(workspace);
});

final userPreferenceActionsProvider = Provider<UserPreferenceActions>((ref) {
  final repository = ref.watch(userPreferencesRepositoryProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return UserPreferenceActions(repository, workspace);
});

class UserPreferenceActions {
  const UserPreferenceActions(this._repository, this._workspace);

  final UserPreferencesRepository _repository;
  final UserWorkspace _workspace;

  Future<void> save(UserPreferences preferences) {
    return _repository.updatePreferences(
      workspace: _workspace,
      preferences: preferences,
    );
  }
}
