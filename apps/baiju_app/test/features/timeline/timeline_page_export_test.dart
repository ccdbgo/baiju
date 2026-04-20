import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/timeline/presentation/pages/timeline_page.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('timeline page shows copy review summary action', (tester) async {
    final now = DateTime.now().toUtc();
    final event = TimelineEventsTableData(
      id: 'timeline-export-1',
      userId: 'local_user',
      eventType: 'todo',
      eventAction: 'completed',
      sourceEntityId: 'todo-1',
      sourceEntityType: 'todo',
      occurredAt: now,
      title: '完成清单整理',
      summary: '把本周清单按优先级重排',
      payloadJson: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'synced',
      localVersion: 1,
      remoteVersion: 1,
      lastSyncedAt: now,
      deviceId: 'device-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedTimelineFilterProvider.overrideWith(
            SelectedTimelineFilterNotifier.new,
          ),
          selectedTimelineRangeProvider.overrideWith(
            SelectedTimelineRangeNotifier.new,
          ),
          timelineSummaryProvider.overrideWith(
            (ref) => Stream<TimelineSummary>.value(
              const TimelineSummary(
                total: 1,
                today: 1,
                distinctSources: 1,
                distinctTypes: 1,
              ),
            ),
          ),
          timelineEventsProvider.overrideWith(
            (ref) => Stream<List<TimelineEventsTableData>>.value(
              <TimelineEventsTableData>[event],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TimelinePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('复制复盘摘要'), findsOneWidget);
  });
}
