import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/pages/habit_page.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final habitA = HabitsTableData(
    id: 'habit-a',
    userId: 'local_user',
    name: '晚间复盘',
    description: null,
    frequencyType: 'daily',
    frequencyRule: 'daily',
    reminderTime: '20:00',
    goalId: 'goal-1',
    progressWeight: 1.0,
    startDate: now,
    status: 'active',
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );
  final habitB = HabitsTableData(
    id: 'habit-b',
    userId: 'local_user',
    name: '晨间阅读',
    description: null,
    frequencyType: 'daily',
    frequencyRule: 'daily',
    reminderTime: '20:00',
    goalId: null,
    progressWeight: 1.0,
    startDate: now,
    status: 'active',
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitSummaryProvider.overrideWith(
            (ref) => Stream<HabitSummary>.value(
              const HabitSummary(total: 2, active: 2, checkedToday: 0),
            ),
          ),
          habitListProvider.overrideWith(
            (ref) => Stream<List<HabitTodayItem>>.value(<HabitTodayItem>[
              HabitTodayItem(habit: habitA, checkedToday: false, record: null),
              HabitTodayItem(habit: habitB, checkedToday: false, record: null),
            ]),
          ),
          goalOptionsProvider.overrideWith(
            (ref) =>
                Stream<List<GoalsTableData>>.value(const <GoalsTableData>[]),
          ),
          pendingReminderCountProvider.overrideWith(
            (ref) => Future<int>.value(1),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HabitPage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('habit page supports search and goal-linked filter', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('晚间复盘'), findsOneWidget);
    expect(find.text('晨间阅读'), findsOneWidget);

    await tester.tap(find.text('仅看已关联目标的习惯'));
    await tester.pumpAndSettle();
    expect(find.text('晚间复盘'), findsOneWidget);
    expect(find.text('晨间阅读'), findsNothing);
  });

  testWidgets('habit page exposes workbench and sort controls', (tester) async {
    await pumpPage(tester);

    expect(find.text('习惯工作台'), findsOneWidget);
    expect(find.text('今日页'), findsOneWidget);
    expect(find.text('目标页'), findsOneWidget);
    expect(find.text('目标优先'), findsOneWidget);
    expect(find.text('提醒优先'), findsOneWidget);
    expect(find.text('名称 A-Z'), findsOneWidget);
  });
}
