import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_export_formatter.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildTimelineReviewSummary outputs metrics and event lines', () {
    final now = DateTime(2026, 4, 17, 9, 30);
    final events = <TimelineEventsTableData>[
      _buildEvent(
        id: 'todo-1',
        eventType: 'todo',
        eventAction: 'completed',
        title: '完成晨间整理',
        summary: '把今天的任务优先级重新梳理了一遍',
        occurredAt: now,
      ),
      _buildEvent(
        id: 'note-1',
        eventType: 'note',
        eventAction: 'updated',
        title: '更新复盘笔记',
        summary: '补充了昨天会议的结论',
        occurredAt: now.subtract(const Duration(hours: 2)),
      ),
    ];

    final text = buildTimelineReviewSummary(
      events: events,
      filter: TimelineFilter.all,
      rangeFilter: const TimelineDateRangeFilter(
        preset: TimelineRangePreset.last7Days,
      ),
      sortLabel: '最新优先',
      searchQuery: '复盘',
      generatedAt: now,
    );

    expect(text, contains('时间线复盘摘要'));
    expect(text, contains('关键词：复盘'));
    expect(text, contains('结果统计：共 2 条事件'));
    expect(text, contains('- 待办：1'));
    expect(text, contains('- 笔记：1'));
    expect(text, contains('1. 04-17 09:30 [待办/完成] 完成晨间整理'));
    expect(text, contains('2. 04-17 07:30 [笔记/更新] 更新复盘笔记'));
  });

  test('buildTimelineReviewSummary handles empty events', () {
    final text = buildTimelineReviewSummary(
      events: const <TimelineEventsTableData>[],
      filter: TimelineFilter.todo,
      rangeFilter: const TimelineDateRangeFilter(
        preset: TimelineRangePreset.last30Days,
      ),
      sortLabel: '最新优先',
      searchQuery: '',
      generatedAt: DateTime(2026, 4, 17, 12),
    );

    expect(text, contains('结果统计：共 0 条事件'));
    expect(text, contains('事件明细：当前筛选下暂无事件。'));
  });

  test('buildTimelineEventSummary and buildTimelineEventPayload format text', () {
    final event = _buildEvent(
      id: 'schedule-1',
      eventType: 'schedule',
      eventAction: 'updated',
      title: '更新周会时间',
      summary: '改到下午三点并通知了所有参与者',
      payloadJson: '{"status":"done","operator":"local_user"}',
      occurredAt: DateTime(2026, 4, 17, 8),
    );

    final summary = buildTimelineEventSummary(
      event,
      generatedAt: DateTime(2026, 4, 17, 12, 30),
    );
    final payload = buildTimelineEventPayload(event);

    expect(summary, contains('时间线事件摘要'));
    expect(summary, contains('标题：更新周会时间'));
    expect(summary, contains('类型：日程'));
    expect(summary, contains('动作：更新'));
    expect(summary, contains('载荷：有（可单独复制）'));
    expect(payload, contains('"status": "done"'));
    expect(payload, contains('"operator": "local_user"'));
  });
}

TimelineEventsTableData _buildEvent({
  required String id,
  required String eventType,
  required String eventAction,
  required String title,
  required DateTime occurredAt,
  String? summary,
  String? payloadJson,
}) {
  return TimelineEventsTableData(
    id: id,
    userId: 'local_user',
    eventType: eventType,
    eventAction: eventAction,
    sourceEntityId: '$eventType-source',
    sourceEntityType: eventType,
    occurredAt: occurredAt,
    title: title,
    summary: summary,
    payloadJson: payloadJson,
    createdAt: occurredAt,
    updatedAt: occurredAt,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: occurredAt,
    deviceId: 'device-1',
  );
}
