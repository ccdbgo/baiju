import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/pages/schedule_page.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final scheduleA = SchedulesTableData(
    id: 'schedule-a',
    userId: 'local_user',
    title: '产品评审会',
    description: '同步版本计划与风险',
    startAt: now,
    endAt: now.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'UTC',
    location: '会议室 A',
    category: '工作',
    color: null,
    status: 'planned',
    recurrenceRule: null,
    reminderMinutesBefore: 15,
    sourceTodoId: null,
    linkedNoteId: null,
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
  final scheduleB = scheduleA.copyWith(
    id: 'schedule-b',
    title: '季度总结',
    isAllDay: true,
    location: const Value('总部'),
    category: const Value('复盘'),
  );

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userPreferencesProvider.overrideWith(
            (ref) => Stream<UserPreferences>.value(const UserPreferences()),
          ),
          scheduleSummaryProvider.overrideWith(
            (ref) => Stream<ScheduleSummary>.value(
              const ScheduleSummary(
                total: 2,
                today: 2,
                upcoming: 2,
                completed: 0,
              ),
            ),
          ),
          scheduleListProvider.overrideWith(
            (ref) => Stream<List<SchedulesTableData>>.value(
              <SchedulesTableData>[scheduleA, scheduleB],
            ),
          ),
          allScheduleListProvider.overrideWith(
            (ref) => Stream<List<SchedulesTableData>>.value(
              <SchedulesTableData>[scheduleA, scheduleB],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SchedulePage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> scrollMainListUntilVisible(
    WidgetTester tester,
    Finder finder,
  ) async {
    for (var i = 0; i < 10 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('schedule page supports multi-field keyword filtering', (
    tester,
  ) async {
    await pumpPage(tester);

    final searchField = find.byKey(const ValueKey('schedule-search-field'));
    final scheduleAEditButton = find.byKey(
      const ValueKey<String>('schedule-list-edit-button-schedule-a'),
    );
    final scheduleBEditButton = find.byKey(
      const ValueKey<String>('schedule-list-edit-button-schedule-b'),
    );

    await scrollMainListUntilVisible(tester, searchField);
    await scrollMainListUntilVisible(tester, scheduleAEditButton);

    expect(scheduleAEditButton, findsOneWidget);
    expect(scheduleBEditButton, findsOneWidget);

    await tester.enterText(searchField, '总部');
    await tester.pumpAndSettle();
    expect(scheduleAEditButton, findsNothing);
    expect(scheduleBEditButton, findsOneWidget);

    await tester.enterText(searchField, '会议室 A');
    await tester.pumpAndSettle();
    expect(scheduleAEditButton, findsOneWidget);
    expect(scheduleBEditButton, findsNothing);
  });

  testWidgets('schedule page exposes workbench and sort controls', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('日程工作台'), findsOneWidget);
    expect(find.text('今日页'), findsOneWidget);
    expect(find.text('时间线'), findsOneWidget);
  });

  testWidgets('schedule page shows extended quick-create fields', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(
      find.byKey(const ValueKey('schedule-quick-is-all-day-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-quick-location-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-quick-category-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-quick-description-field')),
      findsOneWidget,
    );
  });

  testWidgets('schedule page shows search scope and lightweight filters', (
    tester,
  ) async {
    await pumpPage(tester);

    final searchScopeHint = find.byKey(
      const ValueKey('schedule-search-scope-hint'),
    );
    final scheduleAEditButton = find.byKey(
      const ValueKey<String>('schedule-list-edit-button-schedule-a'),
    );
    final scheduleBEditButton = find.byKey(
      const ValueKey<String>('schedule-list-edit-button-schedule-b'),
    );

    await scrollMainListUntilVisible(tester, searchScopeHint);
    await scrollMainListUntilVisible(tester, scheduleAEditButton);

    expect(searchScopeHint, findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-all-day-filter-all')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-all-day-filter-allDay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-all-day-filter-timed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-category-filter-all')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('schedule-all-day-filter-allDay')));
    await tester.pumpAndSettle();
    expect(scheduleAEditButton, findsNothing);
    expect(scheduleBEditButton, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('schedule-all-day-filter-timed')));
    await tester.pumpAndSettle();
    expect(scheduleAEditButton, findsOneWidget);
    expect(scheduleBEditButton, findsNothing);
  });

  testWidgets('schedule edit sheet shows extended fields', (tester) async {
    await pumpPage(tester);

    final editFinder = find.byKey(
      const ValueKey<String>('schedule-list-edit-button-schedule-a'),
    );
    await scrollMainListUntilVisible(tester, editFinder);
    expect(editFinder, findsOneWidget);
    await tester.ensureVisible(editFinder);
    await tester.pumpAndSettle();
    await tester.tap(editFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('schedule-edit-is-all-day-switch')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-edit-location-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-edit-category-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-edit-description-field')),
      findsOneWidget,
    );
  });
}
