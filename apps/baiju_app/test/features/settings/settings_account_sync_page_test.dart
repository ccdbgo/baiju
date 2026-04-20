import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_account_sync_page.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final adminUser = UsersTableData(
    id: 'local_user',
    displayName: '管理员',
    avatarUrl: null,
    authProvider: 'local',
    role: 'admin',
    authProviderUserId: null,
    wechatOpenId: null,
    wechatUnionId: null,
    lastLoginAt: now,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
  );
  final memberUser = UsersTableData(
    id: 'user-1',
    displayName: '普通成员',
    avatarUrl: null,
    authProvider: 'local',
    role: 'member',
    authProviderUserId: null,
    wechatOpenId: null,
    wechatUnionId: null,
    lastLoginAt: now,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
  );

  testWidgets('non-admin sees access restriction', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIsAdminProvider.overrideWith((ref) => false),
          activeUserProfileProvider.overrideWith(
            (ref) => Stream<UsersTableData?>.value(memberUser),
          ),
          userListProvider.overrideWith(
            (ref) => Stream<List<UsersTableData>>.value(<UsersTableData>[]),
          ),
          pendingUserSyncCountProvider.overrideWith(
            (ref) => Stream<int>.value(0),
          ),
        ],
        child: const MaterialApp(home: SettingsAccountSyncPage()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('访问受限'), findsOneWidget);
    expect(find.textContaining('只有管理员用户才能进行用户管理'), findsOneWidget);
    expect(find.text('用户管理台'), findsNothing);
  });

  testWidgets('admin can search and filter users in management console', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIsAdminProvider.overrideWith((ref) => true),
          activeUserProfileProvider.overrideWith(
            (ref) => Stream<UsersTableData?>.value(adminUser),
          ),
          userListProvider.overrideWith(
            (ref) => Stream<List<UsersTableData>>.value(<UsersTableData>[
              adminUser,
              memberUser,
            ]),
          ),
          pendingUserSyncCountProvider.overrideWith(
            (ref) => Stream<int>.value(2),
          ),
        ],
        child: const MaterialApp(home: SettingsAccountSyncPage()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('用户管理台'), findsOneWidget);
    expect(find.text('普通成员'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '普通');
    await tester.pump();

    expect(find.text('普通成员'), findsOneWidget);

    final memberFilterChip = find.byWidgetPredicate(
      (widget) =>
          widget is ChoiceChip &&
          widget.label is Text &&
          (widget.label as Text).data == '普通用户',
    );
    await tester.tap(memberFilterChip);
    await tester.pump();

    expect(find.text('普通成员'), findsOneWidget);
  });

  testWidgets('admin sees bulk action bar after selecting a user', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIsAdminProvider.overrideWith((ref) => true),
          activeUserProfileProvider.overrideWith(
            (ref) => Stream<UsersTableData?>.value(adminUser),
          ),
          userListProvider.overrideWith(
            (ref) => Stream<List<UsersTableData>>.value(<UsersTableData>[
              adminUser,
              memberUser,
            ]),
          ),
          pendingUserSyncCountProvider.overrideWith(
            (ref) => Stream<int>.value(2),
          ),
        ],
        child: const MaterialApp(home: SettingsAccountSyncPage()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.textContaining('已选择 1 个用户'), findsOneWidget);
    expect(find.text('批量设为管理员'), findsOneWidget);
    expect(find.text('批量删除'), findsOneWidget);
  });
}
