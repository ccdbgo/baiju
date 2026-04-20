import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/daos/schedule_dao.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/infrastructure/schedule_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ScheduleRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = ScheduleRepository(database, ScheduleDao(database));
  });

  tearDown(() async {
    await database.close();
  });

  test('createSchedule writes schedule, sync queue and timeline event', () async {
    final created = await repository.createSchedule(
      title: '产品评审会',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.afternoon,
      duration: ScheduleDurationOption.oneHour,
      reminder: ScheduleReminderOption.fifteen,
      recurrence: ScheduleRecurrenceRule.weekdays,
      description: 'sync metadata',
      location: 'A-401',
      category: 'work',
      isAllDay: true,
      sourceTodoId: 'todo-123',
    );

    final schedules = await database.select(database.schedulesTable).get();
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(schedules, hasLength(1));
    expect(schedules.single.title, '产品评审会');
    expect(schedules.single.status, 'planned');
    expect(schedules.single.reminderMinutesBefore, 15);
    expect(schedules.single.description, 'sync metadata');
    expect(schedules.single.location, 'A-401');
    expect(schedules.single.category, 'work');
    expect(schedules.single.isAllDay, isTrue);
    expect(
      schedules.single.recurrenceRule,
      ScheduleRecurrenceRule.weekdays.rule,
    );
    expect(schedules.single.sourceTodoId, 'todo-123');
    expect(created.description, 'sync metadata');
    expect(created.location, 'A-401');
    expect(created.category, 'work');
    expect(created.isAllDay, isTrue);
    expect(created.sourceTodoId, 'todo-123');
    expect(created.recurrenceRule, ScheduleRecurrenceRule.weekdays.rule);
    expect(syncQueue, hasLength(1));
    expect(syncQueue.single.operation, 'create');
    expect(timelineEvents, hasLength(1));
    expect(timelineEvents.single.eventAction, 'created');
    final createPayload =
        jsonDecode(syncQueue.single.payloadJson) as Map<String, dynamic>;
    expect(
      createPayload['recurrence_rule'],
      ScheduleRecurrenceRule.weekdays.rule,
    );
    expect(createPayload['description'], 'sync metadata');
    expect(createPayload['location'], 'A-401');
    expect(createPayload['category'], 'work');
    expect(createPayload['is_all_day'], isTrue);
    final timelinePayload =
        jsonDecode(timelineEvents.single.payloadJson ?? '{}')
            as Map<String, dynamic>;
    expect(
      timelinePayload['recurrence_rule'],
      ScheduleRecurrenceRule.weekdays.rule,
    );
    expect(timelinePayload['description'], 'sync metadata');
    expect(timelinePayload['location'], 'A-401');
    expect(timelinePayload['category'], 'work');
    expect(timelinePayload['is_all_day'], isTrue);
  });

  test('toggleScheduleCompletion updates status and appends tracking records',
      () async {
    await repository.createSchedule(
      title: '完成迭代复盘',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.evening,
      duration: ScheduleDurationOption.halfHour,
      reminder: ScheduleReminderOption.five,
      recurrence: ScheduleRecurrenceRule.none,
    );

    final schedule = (await database.select(database.schedulesTable).get()).single;

    await repository.toggleScheduleCompletion(schedule, true);

    final updatedSchedule =
        (await database.select(database.schedulesTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(updatedSchedule.status, 'completed');
    expect(updatedSchedule.completedAt, isNotNull);
    expect(updatedSchedule.localVersion, 2);
    expect(syncQueue, hasLength(2));
    expect(syncQueue.last.operation, 'update');
    expect(timelineEvents, hasLength(2));
    expect(
      timelineEvents.any((event) => event.eventAction == 'completed'),
      isTrue,
    );
  });

  test('watchSchedules filters today, upcoming and completed lists correctly',
      () async {
    await repository.createSchedule(
      title: '今天同步站会',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.morning,
      duration: ScheduleDurationOption.halfHour,
      reminder: ScheduleReminderOption.none,
      recurrence: ScheduleRecurrenceRule.none,
    );
    await repository.createSchedule(
      title: '明天方案评审',
      day: QuickScheduleDay.tomorrow,
      slot: QuickScheduleSlot.afternoon,
      duration: ScheduleDurationOption.oneHour,
      reminder: ScheduleReminderOption.thirty,
      recurrence: ScheduleRecurrenceRule.weekly,
    );

    final schedules = await database.select(database.schedulesTable).get();
    final todaySchedule =
        schedules.firstWhere((schedule) => schedule.title == '今天同步站会');

    await repository.toggleScheduleCompletion(todaySchedule, true);

    final todayItems =
        await repository.watchSchedules(ScheduleFilter.today).first;
    final upcomingItems =
        await repository.watchSchedules(ScheduleFilter.upcoming).first;
    final completedItems =
        await repository.watchSchedules(ScheduleFilter.completed).first;

    expect(todayItems.any((item) => item.title == '今天同步站会'), isTrue);
    expect(upcomingItems, hasLength(1));
    expect(upcomingItems.single.title, '明天方案评审');
    expect(completedItems, hasLength(1));
    expect(completedItems.single.title, '今天同步站会');
  });

  test('updateSchedule updates title and metadata fields', () async {
    final created = await repository.createSchedule(
      title: '早会',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.morning,
      duration: ScheduleDurationOption.halfHour,
      reminder: ScheduleReminderOption.five,
      recurrence: ScheduleRecurrenceRule.none,
      description: 'old description',
      location: 'old room',
      category: 'old category',
      isAllDay: false,
    );

    final updatedStart = created.startAt.add(const Duration(hours: 2));
    final updatedEnd = updatedStart.add(const Duration(hours: 1));

    await repository.updateSchedule(
      schedule: created,
      title: '项目周会',
      startAt: updatedStart,
      endAt: updatedEnd,
      reminder: ScheduleReminderOption.thirty,
      recurrence: ScheduleRecurrenceRule.monthly,
      description: 'new description',
      location: 'new room',
      category: 'meeting',
      isAllDay: true,
    );

    final updated = (await database.select(database.schedulesTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(updated.title, '项目周会');
    expect(updated.reminderMinutesBefore, 30);
    expect(updated.description, 'new description');
    expect(updated.location, 'new room');
    expect(updated.category, 'meeting');
    expect(updated.isAllDay, isTrue);
    expect(updated.recurrenceRule, ScheduleRecurrenceRule.monthly.rule);
    expect(
      updated.startAt.toUtc().millisecondsSinceEpoch,
      updatedStart.toUtc().millisecondsSinceEpoch,
    );
    final updatePayload =
        jsonDecode(syncQueue.last.payloadJson) as Map<String, dynamic>;
    expect(
      updatePayload['recurrence_rule'],
      ScheduleRecurrenceRule.monthly.rule,
    );
    expect(updatePayload['description'], 'new description');
    expect(updatePayload['location'], 'new room');
    expect(updatePayload['category'], 'meeting');
    expect(updatePayload['is_all_day'], isTrue);
    final updatedTimelineEvent = timelineEvents.firstWhere(
      (event) => event.eventAction == 'updated',
    );
    final updatedTimelinePayload =
        jsonDecode(updatedTimelineEvent.payloadJson ?? '{}')
            as Map<String, dynamic>;
    expect(
      updatedTimelinePayload['recurrence_rule'],
      ScheduleRecurrenceRule.monthly.rule,
    );
    expect(updatedTimelinePayload['description'], 'new description');
    expect(updatedTimelinePayload['location'], 'new room');
    expect(updatedTimelinePayload['category'], 'meeting');
    expect(updatedTimelinePayload['is_all_day'], isTrue);
    expect(
      timelineEvents.any((event) => event.eventAction == 'updated'),
      isTrue,
    );
  });

  test('updateSchedule keeps existing metadata when optional args are omitted',
      () async {
    final created = await repository.createSchedule(
      title: 'keep metadata',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.morning,
      duration: ScheduleDurationOption.halfHour,
      reminder: ScheduleReminderOption.five,
      recurrence: ScheduleRecurrenceRule.none,
      description: 'keep description',
      location: 'keep room',
      category: 'keep category',
      isAllDay: true,
    );

    final updatedStart = created.startAt.add(const Duration(hours: 3));
    final updatedEnd = updatedStart.add(const Duration(hours: 1));

    await repository.updateSchedule(
      schedule: created,
      title: 'keep metadata updated',
      startAt: updatedStart,
      endAt: updatedEnd,
      reminder: ScheduleReminderOption.fifteen,
      recurrence: ScheduleRecurrenceRule.weekly,
    );

    final updated = (await database.select(database.schedulesTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final updatePayload =
        jsonDecode(syncQueue.last.payloadJson) as Map<String, dynamic>;

    expect(updated.description, 'keep description');
    expect(updated.location, 'keep room');
    expect(updated.category, 'keep category');
    expect(updated.isAllDay, isTrue);
    expect(updatePayload['description'], 'keep description');
    expect(updatePayload['location'], 'keep room');
    expect(updatePayload['category'], 'keep category');
    expect(updatePayload['is_all_day'], isTrue);
  });

  test('cancelSchedule and deleteSchedule write lifecycle records', () async {
    final created = await repository.createSchedule(
      title: '取消后删除',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.afternoon,
      duration: ScheduleDurationOption.oneHour,
      reminder: ScheduleReminderOption.five,
      recurrence: ScheduleRecurrenceRule.weekly,
    );

    await repository.cancelSchedule(created);

    final cancelled =
        (await database.select(database.schedulesTable).get()).single;
    expect(cancelled.status, 'cancelled');

    await repository.deleteSchedule(cancelled);

    final deleted = (await database.select(database.schedulesTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(deleted.deletedAt, isNotNull);
    expect(syncQueue.last.operation, 'delete');
    expect(timelineEvents.any((event) => event.eventAction == 'cancelled'), isTrue);
    expect(timelineEvents.any((event) => event.eventAction == 'deleted'), isTrue);
  });

  test('recordScheduleConvertedToTodo writes schedule link payload', () async {
    final created = await repository.createSchedule(
      title: 'link schedule to todo',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.afternoon,
      duration: ScheduleDurationOption.oneHour,
      reminder: ScheduleReminderOption.five,
      recurrence: ScheduleRecurrenceRule.none,
    );

    await repository.recordScheduleConvertedToTodo(
      schedule: created,
      todoId: 'todo-9001',
    );

    final schedule = (await database.select(database.schedulesTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(schedule.localVersion, 2);
    final payload =
        jsonDecode(syncQueue.last.payloadJson) as Map<String, dynamic>;
    expect(payload['action'], 'converted_to_todo');
    expect(payload['target_todo_id'], 'todo-9001');

    final convertedEvent = timelineEvents.firstWhere(
      (event) => event.eventAction == 'converted_to_todo',
    );
    final convertedPayload =
        jsonDecode(convertedEvent.payloadJson ?? '{}') as Map<String, dynamic>;
    expect(convertedPayload['target_todo_id'], 'todo-9001');
  });

  test('postponeScheduleByDays shifts date and appends action payload', () async {
    final created = await repository.createSchedule(
      title: 'postpone me',
      day: QuickScheduleDay.today,
      slot: QuickScheduleSlot.morning,
      duration: ScheduleDurationOption.oneHour,
      reminder: ScheduleReminderOption.none,
      recurrence: ScheduleRecurrenceRule.none,
    );

    final postponed = await repository.postponeScheduleByDays(
      schedule: created,
      days: 1,
    );

    final persisted = (await database.select(database.schedulesTable).get()).single;
    final syncQueue = await database.select(database.syncQueueTable).get();
    final timelineEvents =
        await database.select(database.timelineEventsTable).get();

    expect(
      postponed.startAt.difference(created.startAt).inDays,
      1,
    );
    expect(
      persisted.startAt.difference(created.startAt).inDays,
      1,
    );
    final payload =
        jsonDecode(syncQueue.last.payloadJson) as Map<String, dynamic>;
    expect(payload['action'], 'postponed');
    expect(payload['postpone_days'], 1);
    expect(
      timelineEvents.any((event) => event.eventAction == 'postponed'),
      isTrue,
    );
  });
}
