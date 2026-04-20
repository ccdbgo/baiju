import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/schedule/presentation/widgets/schedule_calendar_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now();
  final dayStart = DateTime(now.year, now.month, now.day);

  SchedulesTableData buildSchedule({
    required String id,
    required String title,
    required DateTime localStart,
    required DateTime localEnd,
    required bool isAllDay,
  }) {
    final utcStart = localStart.toUtc();
    final utcEnd = localEnd.toUtc();
    return SchedulesTableData(
      id: id,
      userId: 'local_user',
      title: title,
      description: null,
      startAt: utcStart,
      endAt: utcEnd,
      isAllDay: isAllDay,
      timezone: 'UTC',
      location: null,
      category: null,
      color: null,
      status: 'planned',
      recurrenceRule: null,
      reminderMinutesBefore: null,
      sourceTodoId: null,
      linkedNoteId: null,
      completedAt: null,
      createdAt: utcStart,
      updatedAt: utcStart,
      deletedAt: null,
      syncStatus: 'synced',
      localVersion: 1,
      remoteVersion: 1,
      lastSyncedAt: utcStart,
      deviceId: 'device-1',
    );
  }

  final allDaySchedule = buildSchedule(
    id: 'all-day',
    title: '全天会议',
    localStart: dayStart,
    localEnd: dayStart.add(const Duration(days: 1)),
    isAllDay: true,
  );
  final timedSchedule = buildSchedule(
    id: 'timed',
    title: '分时评审',
    localStart: dayStart.add(const Duration(hours: 10)),
    localEnd: dayStart.add(const Duration(hours: 11)),
    isAllDay: false,
  );
  final schedules = <SchedulesTableData>[allDaySchedule, timedSchedule];

  testWidgets('day view renders all-day section separately', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              SizedBox(
                width: 1000,
                child: DayScheduleView(
                  focusDate: dayStart,
                  schedules: schedules,
                  pendingScheduleIds: const <String>{},
                  onToggleSchedule: (schedule, completed) async {},
                  onOpenScheduleDetail: (schedule) {},
                  onInlineCreate: (title, startAt, endAt, isAllDay) async {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('day-view-all-day-section')), findsOneWidget);
    expect(find.text('全天安排'), findsOneWidget);
    expect(find.text('全天会议'), findsOneWidget);
  });

  testWidgets('month and year views expose all-day counts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              SizedBox(
                width: 1400,
                child: MonthScheduleView(
                  focusDate: dayStart,
                  schedules: schedules,
                  onOpenScheduleDetail: (_) {},
                  onSelectDate: (_) {},
                  onInlineCreate: (title, startAt, endAt, isAllDay) async {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('全天 1'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              SizedBox(
                width: 1400,
                child: YearScheduleView(
                  focusDate: dayStart,
                  schedules: schedules,
                  onSelectMonth: (_) {},
                  onInlineCreate: (title, startAt, endAt, isAllDay) async {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('全天 1'), findsWidgets);
  });
}
