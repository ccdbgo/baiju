import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test(
    'timelineSummaryProvider aggregates totals for current filter range',
    () async {
      final now = DateTime.now().toUtc();

      await _insertEvent(
        database,
        id: 'todo-1',
        eventType: 'todo',
        sourceEntityId: 'todo-1',
        occurredAt: now,
        title: '完成待办',
      );
      await _insertEvent(
        database,
        id: 'note-1',
        eventType: 'note',
        sourceEntityId: 'note-1',
        occurredAt: now.subtract(const Duration(hours: 2)),
        title: '新增笔记',
      );
      await _insertEvent(
        database,
        id: 'goal-1',
        eventType: 'goal',
        sourceEntityId: 'goal-1',
        occurredAt: now.subtract(const Duration(days: 1)),
        title: '更新目标',
      );

      final subscription = container.listen<AsyncValue<TimelineSummary>>(
        timelineSummaryProvider,
        (previous, next) {},
      );
      addTearDown(subscription.close);
      final summary = await container.read(timelineSummaryProvider.future);

      expect(summary.total, 3);
      expect(summary.today, 2);
      expect(summary.distinctSources, 3);
      expect(summary.distinctTypes, 3);
    },
  );

  test('timelineEventsProvider respects selected filter', () async {
    final now = DateTime.now().toUtc();

    await _insertEvent(
      database,
      id: 'anniversary-1',
      eventType: 'anniversary',
      sourceEntityId: 'anniversary-1',
      occurredAt: now,
      title: '纪念日提醒',
    );
    await _insertEvent(
      database,
      id: 'note-1',
      eventType: 'note',
      sourceEntityId: 'note-1',
      occurredAt: now,
      title: '记录笔记',
    );

    container
        .read(selectedTimelineFilterProvider.notifier)
        .select(TimelineFilter.note);

    final subscription = container
        .listen<AsyncValue<List<TimelineEventsTableData>>>(
          timelineEventsProvider,
          (previous, next) {},
        );
    addTearDown(subscription.close);
    final events = await container.read(timelineEventsProvider.future);

    expect(events, hasLength(1));
    expect(events.single.eventType, 'note');
    expect(events.single.title, '记录笔记');
  });

  test('custom range excludes events outside selected dates', () async {
    final now = DateTime.now().toUtc();

    await _insertEvent(
      database,
      id: 'inside',
      eventType: 'schedule',
      sourceEntityId: 'schedule-1',
      occurredAt: now,
      title: '范围内事件',
    );
    await _insertEvent(
      database,
      id: 'outside',
      eventType: 'schedule',
      sourceEntityId: 'schedule-2',
      occurredAt: now.subtract(const Duration(days: 20)),
      title: '范围外事件',
    );

    final start = DateTime(now.year, now.month, now.day - 2);
    final end = DateTime(now.year, now.month, now.day);
    container
        .read(selectedTimelineRangeProvider.notifier)
        .selectCustomRange(DateTimeRange(start: start, end: end));

    final subscription = container
        .listen<AsyncValue<List<TimelineEventsTableData>>>(
          timelineEventsProvider,
          (previous, next) {},
        );
    addTearDown(subscription.close);
    final events = await container.read(timelineEventsProvider.future);

    expect(events, hasLength(1));
    expect(events.single.title, '范围内事件');
  });
}

Future<void> _insertEvent(
  AppDatabase database, {
  required String id,
  required String eventType,
  required String sourceEntityId,
  required DateTime occurredAt,
  required String title,
}) {
  return database
      .into(database.timelineEventsTable)
      .insert(
        TimelineEventsTableCompanion.insert(
          id: id,
          userId: 'local_user',
          eventType: eventType,
          eventAction: 'created',
          sourceEntityId: sourceEntityId,
          sourceEntityType: eventType,
          occurredAt: occurredAt,
          title: title,
        ),
      );
}
