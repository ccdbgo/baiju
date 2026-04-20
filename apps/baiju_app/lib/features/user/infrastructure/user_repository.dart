import 'package:baiju_app/core/auth/password_utils.dart';
import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/infrastructure/wechat_auth_gateway.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class UserRepository {
  UserRepository(
    this._database, {
    WechatAuthGateway? wechatAuthGateway,
    Uuid? uuid,
  }) : _wechatAuthGateway = wechatAuthGateway ?? const MockWechatAuthGateway(),
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final WechatAuthGateway _wechatAuthGateway;
  final Uuid _uuid;

  static const String _activeUserKey = 'active_user_id';
  static const String _deviceIdKey = 'device_id';
  static const String _defaultUserId = 'admin';

  Stream<List<UsersTableData>> watchUsers() {
    return (_database.select(_database.usersTable)
          ..where((tbl) => tbl.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function($UsersTableTable)>[
            (tbl) => OrderingTerm.desc(tbl.lastLoginAt),
            (tbl) => OrderingTerm.asc(tbl.createdAt),
          ]))
        .watch();
  }

  Future<UserWorkspace> initializeWorkspace() async {
    final now = DateTime.now().toUtc();
    final deviceId = await _getOrCreateDeviceId();
    await _ensureDefaultUser(now);
    final activeUserId = await _readSetting(_activeUserKey) ?? _defaultUserId;
    await _writeSetting(_activeUserKey, activeUserId, now);
    await _touchUser(activeUserId, now);

    return UserWorkspace(userId: activeUserId, deviceId: deviceId);
  }

  Future<UserWorkspace> switchUser({
    required String userId,
    required String deviceId,
  }) async {
    final now = DateTime.now().toUtc();
    await _writeSetting(_activeUserKey, userId, now);
    await _touchUser(userId, now);
    return UserWorkspace(userId: userId, deviceId: deviceId);
  }

  Future<UserWorkspace> createLocalUser({
    required String displayName,
    required String deviceId,
    String? password,
  }) async {
    final now = DateTime.now().toUtc();
    final userId = _uuid.v4();
    final passwordHash =
        password != null && password.isNotEmpty
            ? PasswordUtils.hashPassword(password)
            : null;

    await _database
        .into(_database.usersTable)
        .insert(
          UsersTableCompanion.insert(
            id: userId,
            displayName: displayName.trim(),
            authProvider: const Value('local'),
            role: const Value('member'),
            passwordHash: Value(passwordHash),
            lastLoginAt: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    return switchUser(userId: userId, deviceId: deviceId);
  }

  Future<UserWorkspace> signInWithWechat({
    required UserWorkspace currentWorkspace,
  }) async {
    final identity = await _wechatAuthGateway.signIn();
    final now = DateTime.now().toUtc();

    final existingUser =
        await (_database.select(_database.usersTable)..where(
              (tbl) =>
                  tbl.deletedAt.isNull() &
                  tbl.wechatUnionId.equals(identity.unionId),
            ))
            .getSingleOrNull();

    final targetUserId = existingUser?.id ?? currentWorkspace.userId;

    await (_database.update(
      _database.usersTable,
    )..where((tbl) => tbl.id.equals(targetUserId))).write(
      UsersTableCompanion(
        displayName: Value(
          existingUser?.displayName == '默认用户'
              ? identity.displayName
              : existingUser?.displayName ?? identity.displayName,
        ),
        role: Value(existingUser?.role ?? UserRole.member.value),
        avatarUrl: Value(identity.avatarUrl),
        authProvider: Value(AppUserAuthProvider.wechat.value),
        authProviderUserId: Value(identity.unionId),
        wechatOpenId: Value(identity.openId),
        wechatUnionId: Value(identity.unionId),
        lastLoginAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _writeSetting(_activeUserKey, targetUserId, now);
    return UserWorkspace(
      userId: targetUserId,
      deviceId: currentWorkspace.deviceId,
    );
  }

  Future<UserWorkspace> signOutToLocal({required String deviceId}) async {
    await _ensureDefaultUser(DateTime.now().toUtc());
    return switchUser(userId: _defaultUserId, deviceId: deviceId);
  }

  Future<String> _getOrCreateDeviceId() async {
    final stored = await _readSetting(_deviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final deviceId = 'device-${_uuid.v4()}';
    await _writeSetting(_deviceIdKey, deviceId, DateTime.now().toUtc());
    return deviceId;
  }

  Future<void> _ensureDefaultUser(DateTime now) async {
    final passwordHash = PasswordUtils.hashPassword('admin');
    await _database
        .into(_database.usersTable)
        .insert(
          UsersTableCompanion.insert(
            id: _defaultUserId,
            displayName: 'admin',
            authProvider: const Value('local'),
            role: const Value('admin'),
            passwordHash: Value(passwordHash),
            lastLoginAt: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> updateUserRole({
    required String userId,
    required UserRole role,
  }) async {
    final user = await _findUser(userId);
    if (user == null) {
      throw StateError('User not found.');
    }

    if (user.role == UserRole.admin.value &&
        role != UserRole.admin &&
        await _activeAdminCount() <= 1) {
      throw StateError('At least one admin user must remain.');
    }

    await (_database.update(
      _database.usersTable,
    )..where((tbl) => tbl.id.equals(userId) & tbl.deletedAt.isNull())).write(
      UsersTableCompanion(
        role: Value(role.value),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> updateUsersRole({
    required List<String> userIds,
    required UserRole role,
  }) async {
    final normalizedIds = userIds.toSet().toList();
    if (normalizedIds.isEmpty) {
      return;
    }

    final users =
        await (_database.select(_database.usersTable)..where(
              (tbl) => tbl.id.isIn(normalizedIds) & tbl.deletedAt.isNull(),
            ))
            .get();
    if (users.isEmpty) {
      return;
    }

    if (role != UserRole.admin) {
      final adminsToDemote = users
          .where((user) => user.role == UserRole.admin.value)
          .length;
      if (adminsToDemote > 0 &&
          await _activeAdminCount() - adminsToDemote <= 0) {
        throw StateError('At least one admin user must remain.');
      }
    }

    final now = DateTime.now().toUtc();
    await (_database.update(_database.usersTable)
          ..where((tbl) => tbl.id.isIn(normalizedIds) & tbl.deletedAt.isNull()))
        .write(
          UsersTableCompanion(role: Value(role.value), updatedAt: Value(now)),
        );
  }

  Future<void> deleteUser(String userId) async {
    if (userId == _defaultUserId) {
      throw StateError('The default admin user cannot be deleted.');
    }

    final user = await _findUser(userId);
    if (user == null) {
      throw StateError('User not found.');
    }

    if (user.role == UserRole.admin.value && await _activeAdminCount() <= 1) {
      throw StateError('The last admin user cannot be deleted.');
    }

    await (_database.update(
      _database.usersTable,
    )..where((tbl) => tbl.id.equals(userId) & tbl.deletedAt.isNull())).write(
      UsersTableCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> deleteUsers(List<String> userIds) async {
    final normalizedIds = userIds.toSet().toList();
    if (normalizedIds.isEmpty) {
      return;
    }
    if (normalizedIds.contains(_defaultUserId)) {
      throw StateError('The default admin user cannot be deleted.');
    }

    final users =
        await (_database.select(_database.usersTable)..where(
              (tbl) => tbl.id.isIn(normalizedIds) & tbl.deletedAt.isNull(),
            ))
            .get();
    if (users.isEmpty) {
      return;
    }

    final adminsToDelete = users
        .where((user) => user.role == UserRole.admin.value)
        .length;
    if (adminsToDelete > 0 && await _activeAdminCount() - adminsToDelete <= 0) {
      throw StateError('The last admin user cannot be deleted.');
    }

    final now = DateTime.now().toUtc();
    await (_database.update(_database.usersTable)
          ..where((tbl) => tbl.id.isIn(normalizedIds) & tbl.deletedAt.isNull()))
        .write(
          UsersTableCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
  }

  /// Returns true if the user has no password set (free to switch).
  Future<bool> userHasPassword(String userId) async {
    final user = await _findUser(userId);
    return user?.passwordHash != null && user!.passwordHash!.isNotEmpty;
  }

  /// Verifies the given password against the stored hash.
  Future<bool> verifyUserPassword(String userId, String password) async {
    final user = await _findUser(userId);
    if (user == null) return false;
    final hash = user.passwordHash;
    if (hash == null || hash.isEmpty) return true; // no password set
    return PasswordUtils.verifyPassword(password, hash);
  }

  /// Sets or replaces a user's password (admin action or self-service).
  Future<void> setUserPassword(String userId, String newPassword) async {
    final hash = PasswordUtils.hashPassword(newPassword);
    await (_database.update(_database.usersTable)
          ..where((tbl) => tbl.id.equals(userId) & tbl.deletedAt.isNull()))
        .write(
          UsersTableCompanion(
            passwordHash: Value(hash),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  /// Clears a user's password (admin reset).
  Future<void> clearUserPassword(String userId) async {
    await (_database.update(_database.usersTable)
          ..where((tbl) => tbl.id.equals(userId) & tbl.deletedAt.isNull()))
        .write(
          UsersTableCompanion(
            passwordHash: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> updateDisplayName(String userId, String displayName) async {
    await (_database.update(_database.usersTable)
          ..where((tbl) => tbl.id.equals(userId) & tbl.deletedAt.isNull()))
        .write(
          UsersTableCompanion(
            displayName: Value(displayName.trim()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> _touchUser(String userId, DateTime now) async {
    await (_database.update(
      _database.usersTable,
    )..where((tbl) => tbl.id.equals(userId))).write(
      UsersTableCompanion(lastLoginAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<String?> _readSetting(String key) async {
    final row = await (_database.select(
      _database.appSettingsTable,
    )..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeSetting(String key, String value, DateTime now) {
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

  Future<UsersTableData?> _findUser(String userId) {
    return (_database.select(_database.usersTable)
          ..where((tbl) => tbl.id.equals(userId) & tbl.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<int> _activeAdminCount() async {
    final users =
        await (_database.select(_database.usersTable)..where(
              (tbl) =>
                  tbl.deletedAt.isNull() &
                  tbl.role.equals(UserRole.admin.value),
            ))
            .get();
    return users.length;
  }
}
