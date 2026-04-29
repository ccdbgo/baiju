import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/presentation/pages/goal_page.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final goal = GoalsTableData(
    id: 'goal-1',
    userId: 'local_user',
    title: '完成季度目标',
    description: null,
    goalType: GoalType.stage.value,
    progressMode: GoalProgressMode.mixed.value,
    todoWeight: 0.7,
    habitWeight: 0.3,
    todoUnitWeight: 1.0,
    habitUnitWeight: 0.5,
    status: GoalStatus.active.value,
    priority: 'not_urgent_important',
    startDate: null,
    endDate: null,
    progressValue: 2,
    progressTarget: 10,
    unit: '项',
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
          goalSummaryProvider.overrideWith(
            (ref) => Stream<GoalSummary>.value(
              const GoalSummary(total: 1, active: 1, completed: 0),
            ),
          ),
          goalOverviewListProvider.overrideWith(
            (ref) => Stream<List<GoalOverview>>.value(<GoalOverview>[
              GoalOverview(
                goal: goal,
                linkedTodoCount: 1,
                completedTodoCount: 0,
                linkedHabitCount: 1,
                checkedHabitCount: 0,
                totalHabitWeight: 1,
                checkedHabitWeight: 0,
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: GoalPage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('goal page supports status and keyword filtering', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('完成季度目标'), findsOneWidget);

    final activeStatusChip = find.byWidgetPredicate(
      (widget) =>
          widget is ChoiceChip &&
          widget.label is Text &&
          (widget.label as Text).data == '进行中',
    );
    await tester.tap(activeStatusChip.first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(3), '季度');
    await tester.pumpAndSettle();

    expect(find.text('完成季度目标'), findsOneWidget);
  });

  testWidgets('goal page exposes workbench and sort controls', (tester) async {
    await pumpPage(tester);

    expect(find.text('目标工作台'), findsOneWidget);
    expect(find.text('待办页'), findsOneWidget);
    expect(find.text('习惯页'), findsOneWidget);
    expect(find.text('最近更新'), findsOneWidget);
    expect(find.text('进度优先'), findsOneWidget);
    expect(find.text('标题 A-Z'), findsOneWidget);
  });
}
