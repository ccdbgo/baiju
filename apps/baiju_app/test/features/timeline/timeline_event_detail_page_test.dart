import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/timeline/presentation/pages/timeline_event_detail_page.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('detail page shows summary and payload copy actions', (tester) async {
    final event = _buildEvent(payloadJson: '{"status":"done"}');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timelineEventDetailProvider.overrideWith((ref, eventId) async => event),
          timelineAdjacentEventsProvider.overrideWith(
            (ref, eventId) async => const TimelineAdjacentEvents(),
          ),
          relatedTimelineEventsProvider.overrideWith(
            (ref, eventId) async => const <TimelineEventsTableData>[],
          ),
          sameDayTimelineEventsProvider.overrideWith(
            (ref, eventId) async => const <TimelineEventsTableData>[],
          ),
        ],
        child: const MaterialApp(
          home: TimelineEventDetailPage(eventId: 'timeline-detail-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('复制事件摘要'), findsOneWidget);
    expect(find.text('复制事件载荷'), findsOneWidget);
  });

  testWidgets('detail page hides payload copy action when no payload', (tester) async {
    final event = _buildEvent(payloadJson: null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          timelineEventDetailProvider.overrideWith((ref, eventId) async => event),
          timelineAdjacentEventsProvider.overrideWith(
            (ref, eventId) async => const TimelineAdjacentEvents(),
          ),
          relatedTimelineEventsProvider.overrideWith(
            (ref, eventId) async => const <TimelineEventsTableData>[],
          ),
          sameDayTimelineEventsProvider.overrideWith(
            (ref, eventId) async => const <TimelineEventsTableData>[],
          ),
        ],
        child: const MaterialApp(
          home: TimelineEventDetailPage(eventId: 'timeline-detail-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('复制事件摘要'), findsOneWidget);
    expect(find.text('复制事件载荷'), findsNothing);
  });
}

TimelineEventsTableData _buildEvent({required String? payloadJson}) {
  final now = DateTime.now().toUtc();
  return TimelineEventsTableData(
    id: 'timeline-detail-1',
    userId: 'local_user',
    eventType: 'todo',
    eventAction: 'completed',
    sourceEntityId: 'todo-1',
    sourceEntityType: 'todo',
    occurredAt: now,
    title: '完成关键待办',
    summary: '将今天最高优先级任务处理完成',
    payloadJson: payloadJson,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );
}
