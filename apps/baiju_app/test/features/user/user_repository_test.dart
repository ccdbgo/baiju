import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/infrastructure/user_repository.dart';
import 'package:baiju_app/features/user/infrastructure/wechat_auth_gateway.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late UserRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = UserRepository(
      database,
      wechatAuthGateway: const MockWechatAuthGateway(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('initializeWorkspace creates default user and device id', () async {
    final workspace = await repository.initializeWorkspace();
    final users = await database.select(database.usersTable).get();
    final defaultUser = users.firstWhere((user) => user.id == 'local_user');

    expect(workspace.userId, 'local_user');
    expect(workspace.deviceId, startsWith('device-'));
    expect(users.any((user) => user.id == 'local_user'), isTrue);
    expect(defaultUser.role, UserRole.admin.value);
  });

  test('signInWithWechat binds identity to internal user id', () async {
    final initial = await repository.initializeWorkspace();
    final signedIn = await repository.signInWithWechat(
      currentWorkspace: initial,
    );

    final activeUser = await (database.select(
      database.usersTable,
    )..where((tbl) => tbl.id.equals(signedIn.userId))).getSingle();

    expect(signedIn.userId, initial.userId);
    expect(activeUser.authProvider, AppUserAuthProvider.wechat.value);
    expect(activeUser.wechatUnionId, 'mock-wechat-union-id');
  });

  test('createLocalUser defaults to member role', () async {
    final workspace = await repository.initializeWorkspace();
    final created = await repository.createLocalUser(
      displayName: '测试成员',
      deviceId: workspace.deviceId,
    );

    final user = await (database.select(
      database.usersTable,
    )..where((tbl) => tbl.id.equals(created.userId))).getSingle();

    expect(user.displayName, '测试成员');
    expect(user.role, UserRole.member.value);
  });

  test('updateUserRole persists admin/member changes', () async {
    final workspace = await repository.initializeWorkspace();
    final created = await repository.createLocalUser(
      displayName: '待提升用户',
      deviceId: workspace.deviceId,
    );

    await repository.updateUserRole(
      userId: created.userId,
      role: UserRole.admin,
    );

    final updated = await (database.select(
      database.usersTable,
    )..where((tbl) => tbl.id.equals(created.userId))).getSingle();

    expect(updated.role, UserRole.admin.value);
  });

  test('cannot demote the last admin user', () async {
    await repository.initializeWorkspace();

    expect(
      () => repository.updateUserRole(
        userId: 'local_user',
        role: UserRole.member,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('deleteUser soft deletes a member user', () async {
    final workspace = await repository.initializeWorkspace();
    final created = await repository.createLocalUser(
      displayName: '待删除用户',
      deviceId: workspace.deviceId,
    );

    await repository.deleteUser(created.userId);

    final deleted = await (database.select(
      database.usersTable,
    )..where((tbl) => tbl.id.equals(created.userId))).getSingle();

    expect(deleted.deletedAt, isNotNull);
  });

  test('cannot delete the last admin user', () async {
    await repository.initializeWorkspace();

    expect(
      () => repository.deleteUser('local_user'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'updateUsersRole supports batch promotion and preserves admin safety',
    () async {
      final workspace = await repository.initializeWorkspace();
      final first = await repository.createLocalUser(
        displayName: '成员 A',
        deviceId: workspace.deviceId,
      );
      final second = await repository.createLocalUser(
        displayName: '成员 B',
        deviceId: workspace.deviceId,
      );

      await repository.updateUsersRole(
        userIds: <String>[first.userId, second.userId],
        role: UserRole.admin,
      );

      final updated =
          await (database.select(database.usersTable)..where(
                (tbl) => tbl.id.isIn(<String>[first.userId, second.userId]),
              ))
              .get();

      expect(
        updated.every((user) => user.role == UserRole.admin.value),
        isTrue,
      );
    },
  );

  test(
    'deleteUsers soft deletes multiple users but protects final admin',
    () async {
      final workspace = await repository.initializeWorkspace();
      final first = await repository.createLocalUser(
        displayName: '成员 A',
        deviceId: workspace.deviceId,
      );
      final second = await repository.createLocalUser(
        displayName: '成员 B',
        deviceId: workspace.deviceId,
      );

      await repository.deleteUsers(<String>[first.userId, second.userId]);

      final deleted =
          await (database.select(database.usersTable)..where(
                (tbl) => tbl.id.isIn(<String>[first.userId, second.userId]),
              ))
              .get();

      expect(deleted.every((user) => user.deletedAt != null), isTrue);

      expect(
        () => repository.deleteUsers(<String>['local_user']),
        throwsA(isA<StateError>()),
      );
    },
  );
}
