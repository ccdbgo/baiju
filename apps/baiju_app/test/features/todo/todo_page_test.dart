import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/pages/todo_page.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final todoA = TodosTableData(
    id: 'todo-a',
    userId: 'local_user',
    title: '整理会议纪要',
    description: null,
    priority: 'high',
    status: 'open',
    dueAt: now,
    plannedAt: now,
    listName: null,
    goalId: null,
    linkedNoteId: null,
    convertedScheduleId: null,
    completedAt: null,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );
  final todoB = todoA.copyWith(id: 'todo-b', title: '发送日报', priority: 'medium');

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todoSummaryProvider.overrideWith(
            (ref) => Stream<TodoSummary>.value(
              const TodoSummary(total: 2, active: 2, today: 1, completed: 0),
            ),
          ),
          todoListProvider.overrideWith(
            (ref) => Stream<List<TodosTableData>>.value(<TodosTableData>[
              todoA,
              todoB,
            ]),
          ),
          goalOptionsProvider.overrideWith(
            (ref) =>
                Stream<List<GoalsTableData>>.value(const <GoalsTableData>[]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TodoPage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('todo page supports keyword filtering', (tester) async {
    await pumpPage(tester);

    expect(find.text('整理会议纪要'), findsOneWidget);
    expect(find.text('发送日报'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '日报');
    await tester.pumpAndSettle();

    expect(find.text('发送日报'), findsOneWidget);
    expect(find.text('整理会议纪要'), findsNothing);
  });

  testWidgets('todo page exposes workbench and sort controls', (tester) async {
    await pumpPage(tester);

    expect(find.text('待办工作台'), findsOneWidget);
    expect(find.text('今日页'), findsOneWidget);
    expect(find.text('时间线'), findsOneWidget);
    expect(find.text('最近更新'), findsOneWidget);
    expect(find.text('优先级'), findsOneWidget);
    expect(find.text('截止时间'), findsOneWidget);
  });
}
