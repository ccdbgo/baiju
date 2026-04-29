import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/schedule/presentation/pages/schedule_detail_page.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final baseSchedule = SchedulesTableData(
    id: 'schedule-detail-a',
    userId: 'local_user',
    title: '日程详情测试',
    description: '用于校验联动动作入口',
    startAt: now,
    endAt: now.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'UTC',
    location: '会议室 A',
    category: '工作',
    color: null,
    status: 'planned',
    priority: 'not_urgent_important',
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

  Future<void> pumpDetailPage(
    WidgetTester tester, {
    required SchedulesTableData schedule,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleDetailProvider.overrideWith((ref, scheduleId) {
            if (scheduleId != schedule.id) {
              return Stream<SchedulesTableData?>.value(null);
            }
            return Stream<SchedulesTableData?>.value(schedule);
          }),
          relatedNoteListProvider.overrideWith(
            (ref, target) => Stream<List<NotesTableData>>.value(
              const <NotesTableData>[],
            ),
          ),
        ],
        child: MaterialApp(home: ScheduleDetailPage(scheduleId: schedule.id)),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> scrollListUntilVisible(
    WidgetTester tester,
    Finder finder,
  ) async {
    final listFinder = find.byType(ListView).first;
    for (var i = 0; i < 8 && finder.evaluate().isEmpty; i++) {
      await tester.drag(listFinder, const Offset(0, -250));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('schedule detail page shows linkage action entries', (
    tester,
  ) async {
    await pumpDetailPage(tester, schedule: baseSchedule);

    final convertFinder = find.byKey(
      const ValueKey('schedule-detail-action-convert-to-todo'),
    );
    await scrollListUntilVisible(tester, convertFinder);

    expect(convertFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey('schedule-detail-action-sync-habit-record')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('schedule-detail-action-postpone')),
      findsOneWidget,
    );
  });

  testWidgets('postpone action is disabled for non-planned schedule', (
    tester,
  ) async {
    await pumpDetailPage(
      tester,
      schedule: baseSchedule.copyWith(status: 'completed'),
    );

    final postponeFinder = find.byKey(
      const ValueKey('schedule-detail-action-postpone'),
    );
    await scrollListUntilVisible(tester, postponeFinder);

    final postponeButton = tester.widget<OutlinedButton>(postponeFinder);
    expect(postponeButton.onPressed, isNull);
  });
}
