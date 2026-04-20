import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:intl/intl.dart';

String buildTimelineReviewSummary({
  required List<TimelineEventsTableData> events,
  required TimelineFilter filter,
  required TimelineDateRangeFilter rangeFilter,
  required String sortLabel,
  required String searchQuery,
  DateTime? generatedAt,
}) {
  final generated = (generatedAt ?? DateTime.now()).toLocal();
  final dayCount = events
      .map((event) => _dateOnly(event.occurredAt.toLocal()))
      .toSet()
      .length;
  final sourceCount = events
      .map((event) => '${event.sourceEntityType}:${event.sourceEntityId}')
      .toSet()
      .length;
  final typeCounter = <String, int>{};
  for (final event in events) {
    final label = timelineEventTypeLabel(event.eventType);
    typeCounter[label] = (typeCounter[label] ?? 0) + 1;
  }
  final sortedTypes = typeCounter.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final buffer = StringBuffer()
    ..writeln('时间线复盘摘要')
    ..writeln('生成时间：${DateFormat('yyyy年M月d日 HH:mm').format(generated)}')
    ..writeln('筛选条件：${filter.label}｜${_rangeLabel(rangeFilter)}｜$sortLabel');

  if (searchQuery.isNotEmpty) {
    buffer.writeln('关键词：$searchQuery');
  }

  buffer.writeln(
    '结果统计：共 ${events.length} 条事件，覆盖 $dayCount 天，来源对象 $sourceCount 个',
  );

  if (sortedTypes.isNotEmpty) {
    buffer.writeln('类型分布：');
    for (final item in sortedTypes) {
      buffer.writeln('- ${item.key}：${item.value}');
    }
  }

  if (events.isEmpty) {
    buffer.writeln('事件明细：当前筛选下暂无事件。');
    return buffer.toString().trim();
  }

  buffer.writeln('事件明细：');
  final limitedEvents = events.take(20).toList();
  for (var i = 0; i < limitedEvents.length; i++) {
    final event = limitedEvents[i];
    final occurredAt = DateFormat(
      'MM-dd HH:mm',
    ).format(event.occurredAt.toLocal());
    buffer.writeln(
      '${i + 1}. $occurredAt [${timelineEventTypeLabel(event.eventType)}/${timelineEventActionLabel(event.eventAction)}] ${event.title}',
    );
    final summary = event.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('   摘要：${_oneLine(summary)}');
    }
  }
  if (events.length > limitedEvents.length) {
    buffer.writeln('...其余 ${events.length - limitedEvents.length} 条已省略');
  }

  return buffer.toString().trim();
}

String buildTimelineEventSummary(
  TimelineEventsTableData event, {
  DateTime? generatedAt,
}) {
  final generated = (generatedAt ?? DateTime.now()).toLocal();
  final occurredAt = event.occurredAt.toLocal();
  final payload = event.payloadJson?.trim() ?? '';

  final buffer = StringBuffer()
    ..writeln('时间线事件摘要')
    ..writeln('导出时间：${DateFormat('yyyy年M月d日 HH:mm').format(generated)}')
    ..writeln('标题：${event.title}')
    ..writeln('发生时间：${DateFormat('yyyy年M月d日 HH:mm').format(occurredAt)}')
    ..writeln('类型：${timelineEventTypeLabel(event.eventType)}')
    ..writeln('动作：${timelineEventActionLabel(event.eventAction)}')
    ..writeln(
      '来源：${timelineEventTypeLabel(event.sourceEntityType)} / ${event.sourceEntityId}',
    )
    ..writeln('载荷：${payload.isEmpty ? '无' : '有（可单独复制）'}');

  final summary = event.summary?.trim();
  if (summary != null && summary.isNotEmpty) {
    buffer.writeln('摘要：${_oneLine(summary)}');
  }

  return buffer.toString().trim();
}

String buildTimelineEventPayload(TimelineEventsTableData event) {
  final payload = event.payloadJson?.trim() ?? '';
  if (payload.isEmpty) {
    return '当前事件没有载荷数据。';
  }
  try {
    final decoded = jsonDecode(payload);
    return const JsonEncoder.withIndent('  ').convert(decoded);
  } catch (_) {
    return payload;
  }
}

String timelineEventTypeLabel(String eventType) {
  switch (eventType) {
    case 'schedule':
      return '日程';
    case 'todo':
      return '待办';
    case 'habit':
      return '习惯';
    case 'anniversary':
      return '纪念日';
    case 'goal':
      return '目标';
    case 'note':
      return '笔记';
    default:
      return eventType;
  }
}

String timelineEventActionLabel(String action) {
  switch (action) {
    case 'created':
      return '创建';
    case 'updated':
      return '更新';
    case 'completed':
      return '完成';
    case 'checked_in':
      return '打卡';
    case 'scheduled':
      return '转日程';
    case 'archived':
      return '归档';
    case 'paused':
      return '暂停';
    case 'resumed':
      return '恢复';
    case 'deleted':
      return '删除';
    case 'cancelled':
      return '取消';
    default:
      return action;
  }
}

String _rangeLabel(TimelineDateRangeFilter rangeFilter) {
  if (rangeFilter.preset != TimelineRangePreset.custom ||
      rangeFilter.range == null) {
    return rangeFilter.preset.label;
  }
  final start = DateFormat('M月d日').format(rangeFilter.range!.start);
  final end = DateFormat('M月d日').format(rangeFilter.range!.end);
  return '${rangeFilter.preset.label}（$start - $end）';
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

String _oneLine(String value) {
  return value.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
