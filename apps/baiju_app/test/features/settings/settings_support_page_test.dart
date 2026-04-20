import 'package:baiju_app/features/settings/domain/app_support_draft.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_support_page.dart';
import 'package:baiju_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('support page renders persisted draft data and quick links', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSupportDraftProvider.overrideWith(
            (ref) => Stream<AppSupportDraft>.value(
              const AppSupportDraft(
                category: SupportCategory.bug,
                contact: 'tester@example.com',
                message: '进入首页后白屏',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: SettingsSupportPage()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('常用去向'), findsOneWidget);
    expect(find.text('提醒中心'), findsOneWidget);
    expect(find.text('账号与同步'), findsOneWidget);
    expect(find.text('关于应用'), findsOneWidget);
    expect(find.text('反馈草稿'), findsOneWidget);
    expect(find.text('Bug 反馈'), findsWidgets);
    expect(find.text('tester@example.com'), findsOneWidget);
    expect(find.text('进入首页后白屏'), findsOneWidget);
  });
}
