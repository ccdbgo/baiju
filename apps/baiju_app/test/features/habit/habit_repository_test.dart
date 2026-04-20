import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/habit_dao.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/infrastructure/habit_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late HabitRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = HabitRepository(database, HabitDao(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('createHabit writes habit and timeline event', () async {
    await repository.createHabit(
      name: '晚间复盘',
      reminderTime: HabitReminderPreset.evening.value,
    );

    final habits = await database.select(database.habitsTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(habits, hasLength(1));
    expect(habits.single.name, '晚间复盘');
    expect(habits.single.reminderTime, '20:00');
    expect(timelineEvents, hasLength(1));
    expect(timelineEvents.single.eventAction, 'created');
  });

  test('toggleHabitCheckIn creates or updates today record', () async {
    await repository.createHabit(
      name: '晨间阅读',
      reminderTime: HabitReminderPreset.morning.value,
    );

    final item = (await repository.watchHabitsForToday().first).single;

    await repository.toggleHabitCheckIn(item, true);

    final records = await database.select(database.habitRecordsTable).get();
    expect(records, hasLength(1));
    expect(records.single.status, 'done');

    final refreshedItem = (await repository.watchHabitsForToday().first).single;
    await repository.toggleHabitCheckIn(refreshedItem, false);

    final updatedRecords =
        await database.select(database.habitRecordsTable).get();
    expect(updatedRecords.single.status, 'skipped');
  });

  test('updateHabit updates name and reminder time', () async {
    await repository.createHabit(
      name: '晨间阅读',
      reminderTime: HabitReminderPreset.morning.value,
    );

    final habit = (await database.select(database.habitsTable).get()).single;

    await repository.updateHabit(
      habit: habit,
      name: '晚间阅读',
      reminderTime: '21:30',
    );

    final updated = (await database.select(database.habitsTable).get()).single;
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(updated.name, '晚间阅读');
    expect(updated.reminderTime, '21:30');
    expect(
      timelineEvents.any((event) => event.eventAction == 'updated'),
      isTrue,
    );
  });

  test('setHabitPaused blocks check-in and deleteHabit soft deletes', () async {
    await repository.createHabit(
      name: '暂停中的习惯',
      reminderTime: HabitReminderPreset.evening.value,
    );

    final habit = (await database.select(database.habitsTable).get()).single;
    await repository.setHabitPaused(habit, true);

    final pausedHabit = (await database.select(database.habitsTable).get()).single;
    expect(pausedHabit.status, 'paused');

    final pausedItem = (await repository.watchHabitsForToday().first).single;
    await repository.toggleHabitCheckIn(pausedItem, true);

    final records = await database.select(database.habitRecordsTable).get();
    expect(records, isEmpty);

    await repository.deleteHabit(pausedHabit);

    final deletedHabit = (await database.select(database.habitsTable).get()).single;
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(deletedHabit.deletedAt, isNotNull);
    expect(timelineEvents.any((event) => event.eventAction == 'paused'), isTrue);
    expect(timelineEvents.any((event) => event.eventAction == 'deleted'), isTrue);
  });

  test('backfillHabitRecord upserts record for same day', () async {
    await repository.createHabit(
      name: '补打卡测试',
      reminderTime: HabitReminderPreset.evening.value,
    );

    var habit = (await database.select(database.habitsTable).get()).single;
    final targetDate = DateTime.now().subtract(const Duration(days: 2));

    await repository.backfillHabitRecord(
      habit: habit,
      recordDate: targetDate,
      status: HabitRecordStatus.done,
    );

    habit = (await database.select(database.habitsTable).get()).single;
    await repository.backfillHabitRecord(
      habit: habit,
      recordDate: targetDate,
      status: HabitRecordStatus.skipped,
    );

    final records = await database.select(database.habitRecordsTable).get();
    final dayStart = DateTime.utc(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    expect(records, hasLength(1));
    expect(records.single.recordDate.toUtc().year, dayStart.year);
    expect(records.single.recordDate.toUtc().month, dayStart.month);
    expect(records.single.recordDate.toUtc().day, dayStart.day);
    expect(records.single.status, 'skipped');
  });

  test('watchHabitDetailInsights returns streak and completion stats', () async {
    await repository.createHabit(
      name: '统计测试',
      reminderTime: HabitReminderPreset.morning.value,
    );

    Future<void> backfillAt(int daysAgo, HabitRecordStatus status) async {
      final latestHabit = (await database.select(database.habitsTable).get()).single;
      final date = DateTime.now().subtract(Duration(days: daysAgo));
      await repository.backfillHabitRecord(
        habit: latestHabit,
        recordDate: date,
        status: status,
      );
    }

    await backfillAt(0, HabitRecordStatus.done);
    await backfillAt(1, HabitRecordStatus.done);
    await backfillAt(2, HabitRecordStatus.skipped);
    await backfillAt(3, HabitRecordStatus.done);
    await backfillAt(5, HabitRecordStatus.done);
    await backfillAt(6, HabitRecordStatus.skipped);

    final habit = (await database.select(database.habitsTable).get()).single;
    final insights = await repository.watchHabitDetailInsights(habit.id).first;

    expect(insights.stats7Days.doneDays, 4);
    expect(insights.stats7Days.skippedDays, 2);
    expect(insights.stats7Days.missingDays, 1);
    expect(insights.stats7Days.currentStreak, 2);
    expect(insights.stats7Days.longestStreak, 2);
    expect(insights.stats7Days.completionRate, closeTo(4 / 7, 0.0001));
    expect(insights.stats30Days.totalDays, 30);
    expect(insights.recentRecords.first.status, HabitRecordStatus.done);
  });

  test('syncHabitRecordFromSchedule writes source schedule id', () async {
    await repository.createHabit(
      name: 'schedule linked habit',
      reminderTime: HabitReminderPreset.morning.value,
    );

    final habit = (await database.select(database.habitsTable).get()).single;
    final now = DateTime.now().toUtc();
    final recordDate = DateTime.utc(now.year, now.month, now.day - 1, 9);
    await database.into(database.schedulesTable).insert(
          SchedulesTableCompanion.insert(
            id: 'schedule-sync-habit-1',
            userId: 'local',
            title: 'habit source schedule',
            startAt: recordDate,
            endAt: recordDate.add(const Duration(hours: 1)),
            createdAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value('synced'),
            localVersion: const Value(1),
            deviceId: const Value('local'),
          ),
        );
    final schedule = (await database.select(database.schedulesTable).get()).single;

    final recordId = await repository.syncHabitRecordFromSchedule(
      habit: habit,
      schedule: schedule,
      status: HabitRecordStatus.done,
    );

    final records = await database.select(database.habitRecordsTable).get();
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(recordId, isNotNull);
    expect(records, hasLength(1));
    expect(records.single.sourceScheduleId, schedule.id);
    expect(records.single.status, HabitRecordStatus.done.value);

    final payload =
        jsonDecode(syncQueue.last.payloadJson) as Map<String, dynamic>;
    expect(payload['source_schedule_id'], schedule.id);
    expect(payload['habit_id'], habit.id);
    expect(
      timelineEvents.any((event) => event.eventAction == 'synced_from_schedule'),
      isTrue,
    );
  });
}
