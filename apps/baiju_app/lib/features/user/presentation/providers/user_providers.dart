import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/infrastructure/user_repository.dart';
import 'package:baiju_app/features/user/infrastructure/wechat_auth_gateway.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final wechatAuthGatewayProvider = Provider<WechatAuthGateway>((ref) {
  return const MockWechatAuthGateway();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final gateway = ref.watch(wechatAuthGatewayProvider);
  return UserRepository(database, wechatAuthGateway: gateway);
});

final currentUserWorkspaceProvider =
    NotifierProvider<CurrentUserWorkspaceNotifier, UserWorkspace>(
      CurrentUserWorkspaceNotifier.new,
    );

final activeUserProfileProvider = StreamProvider.autoDispose<UsersTableData?>((
  ref,
) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.usersTable)..where(
        (tbl) => tbl.deletedAt.isNull() & tbl.id.equals(workspace.userId),
      ))
      .watchSingleOrNull();
});

final currentUserRoleProvider = Provider<UserRole>((ref) {
  return ref
      .watch(activeUserProfileProvider)
      .maybeWhen(
        data: (user) => UserRole.fromValue(user?.role ?? UserRole.member.value),
        orElse: () => UserRole.member,
      );
});

final currentUserIsAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserRoleProvider) == UserRole.admin;
});

final userListProvider = StreamProvider.autoDispose<List<UsersTableData>>((
  ref,
) {
  final repository = ref.watch(userRepositoryProvider);
  return repository.watchUsers();
});

final pendingUserSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return (database.select(database.syncQueueTable)..where(
        (tbl) =>
            tbl.userId.equals(workspace.userId) & tbl.status.isNotValue('done'),
      ))
      .watch()
      .map((items) => items.length);
});

final userBootstrapControllerProvider = Provider<UserBootstrapController>((
  ref,
) {
  final repository = ref.watch(userRepositoryProvider);
  return UserBootstrapController(
    repository,
    ref.read(currentUserWorkspaceProvider.notifier),
  );
});

final userActionsProvider = Provider<UserActions>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  final notifier = ref.read(currentUserWorkspaceProvider.notifier);
  final isAdmin = ref.watch(currentUserIsAdminProvider);
  return UserActions(repository, notifier, isAdmin: isAdmin);
});

class CurrentUserWorkspaceNotifier extends Notifier<UserWorkspace> {
  @override
  UserWorkspace build() {
    return const UserWorkspace.local();
  }

  void setWorkspace(UserWorkspace workspace) {
    state = workspace;
  }

  UserWorkspace get currentWorkspace => state;
}

class UserBootstrapController {
  const UserBootstrapController(this._repository, this._notifier);

  final UserRepository _repository;
  final CurrentUserWorkspaceNotifier _notifier;

  Future<void> initialize() async {
    final workspace = await _repository.initializeWorkspace();
    _notifier.setWorkspace(workspace);
  }
}

class UserActions {
  const UserActions(this._repository, this._notifier, {required bool isAdmin})
    : _isAdmin = isAdmin;

  final UserRepository _repository;
  final CurrentUserWorkspaceNotifier _notifier;
  final bool _isAdmin;

  Future<void> createLocalUser(String displayName, {String? password}) async {
    _ensureAdmin();
    final workspace = await _repository.createLocalUser(
      displayName: displayName,
      deviceId: _notifier.currentWorkspace.deviceId,
      password: password,
    );
    _notifier.setWorkspace(workspace);
  }

  Future<void> switchUser(String userId) async {
    _ensureAdmin();
    final workspace = await _repository.switchUser(
      userId: userId,
      deviceId: _notifier.currentWorkspace.deviceId,
    );
    _notifier.setWorkspace(workspace);
  }

  Future<bool> verifyUserPassword(String userId, String password) {
    return _repository.verifyUserPassword(userId, password);
  }

  Future<bool> userHasPassword(String userId) {
    return _repository.userHasPassword(userId);
  }

  Future<void> setUserPassword(String userId, String newPassword) {
    _ensureAdmin();
    return _repository.setUserPassword(userId, newPassword);
  }

  Future<void> clearUserPassword(String userId) {
    _ensureAdmin();
    return _repository.clearUserPassword(userId);
  }

  Future<void> updateDisplayName(String userId, String displayName) {
    _ensureAdmin();
    return _repository.updateDisplayName(userId, displayName);
  }

  Future<void> signInWithWechat() async {
    _ensureAdmin();
    final workspace = await _repository.signInWithWechat(
      currentWorkspace: _notifier.currentWorkspace,
    );
    _notifier.setWorkspace(workspace);
  }

  Future<void> signOutToLocal() async {
    _ensureAdmin();
    final workspace = await _repository.signOutToLocal(
      deviceId: _notifier.currentWorkspace.deviceId,
    );
    _notifier.setWorkspace(workspace);
  }

  Future<void> updateUserRole({
    required String userId,
    required UserRole role,
  }) {
    _ensureAdmin();
    return _repository.updateUserRole(userId: userId, role: role);
  }

  Future<void> updateUsersRole({
    required List<String> userIds,
    required UserRole role,
  }) {
    _ensureAdmin();
    return _repository.updateUsersRole(userIds: userIds, role: role);
  }

  Future<void> deleteUser(String userId) {
    _ensureAdmin();
    return _repository.deleteUser(userId);
  }

  Future<void> deleteUsers(List<String> userIds) {
    _ensureAdmin();
    return _repository.deleteUsers(userIds);
  }

  void _ensureAdmin() {
    if (!_isAdmin) {
      throw StateError('Only admin users can manage users.');
    }
  }
}
