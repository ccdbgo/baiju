import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_page.dart';
import 'package:baiju_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
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

  testWidgets('settings page shows visible quick access section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeUserProfileProvider.overrideWith(
            (ref) => Stream<UsersTableData?>.value(adminUser),
          ),
          currentUserRoleProvider.overrideWith((ref) => UserRole.admin),
          currentUserIsAdminProvider.overrideWith((ref) => true),
          userListProvider.overrideWith(
            (ref) =>
                Stream<List<UsersTableData>>.value(<UsersTableData>[adminUser]),
          ),
          pendingUserSyncCountProvider.overrideWith(
            (ref) => Stream<int>.value(3),
          ),
          pendingReminderCountProvider.overrideWith(
            (ref) => Future<int>.value(2),
          ),
          appDisplaySettingsProvider.overrideWith(
            (ref) =>
                Stream<AppDisplaySettings>.value(const AppDisplaySettings()),
          ),
          userPreferencesProvider.overrideWith(
            (ref) => Stream<UserPreferences>.value(const UserPreferences()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('常用入口'), findsOneWidget);
    expect(find.text('用户管理'), findsOneWidget);
    expect(find.text('提醒 2'), findsOneWidget);
    expect(find.text('首页显示'), findsWidgets);
    expect(find.text('反馈支持'), findsOneWidget);
    expect(find.text('同步队列 3'), findsOneWidget);
  });
}
