import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/timeline/presentation/pages/timeline_page.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final laterEvent = TimelineEventsTableData(
    id: 'timeline-2',
    userId: 'local_user',
    eventType: 'todo',
    eventAction: 'completed',
    sourceEntityId: 'todo-2',
    sourceEntityType: 'todo',
    occurredAt: now,
    title: '较晚事件',
    summary: '处理了第二个待办',
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
  final earlierEvent = TimelineEventsTableData(
    id: 'timeline-1',
    userId: 'local_user',
    eventType: 'note',
    eventAction: 'created',
    sourceEntityId: 'note-1',
    sourceEntityType: 'note',
    occurredAt: now.subtract(const Duration(hours: 2)),
    title: '较早事件',
    summary: '补充了第一条笔记',
    payloadJson: null,
    createdAt: now.subtract(const Duration(hours: 2)),
    updatedAt: now.subtract(const Duration(hours: 2)),
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now.subtract(const Duration(hours: 2)),
    deviceId: 'device-1',
  );

  testWidgets('timeline page supports search and sort controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
                total: 2,
                today: 2,
                distinctSources: 2,
                distinctTypes: 2,
              ),
            ),
          ),
          timelineEventsProvider.overrideWith(
            (ref) => Stream<List<TimelineEventsTableData>>.value(
              <TimelineEventsTableData>[laterEvent, earlierEvent],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TimelinePage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('搜索时间线'), findsOneWidget);
    expect(find.text('当前结果'), findsOneWidget);
    expect(find.text('打开原始对象'), findsNWidgets(2));

    final laterBeforeSort = tester.getTopLeft(find.text('较晚事件')).dy;
    final earlierBeforeSort = tester.getTopLeft(find.text('较早事件')).dy;
    expect(laterBeforeSort, lessThan(earlierBeforeSort));

    await tester.tap(find.text('最早优先'));
    await tester.pumpAndSettle();

    final laterAfterSort = tester.getTopLeft(find.text('较晚事件')).dy;
    final earlierAfterSort = tester.getTopLeft(find.text('较早事件')).dy;
    expect(earlierAfterSort, lessThan(laterAfterSort));

    await tester.enterText(find.byType(TextField), '笔记');
    await tester.pumpAndSettle();

    expect(find.text('较早事件'), findsOneWidget);
    expect(find.text('较晚事件'), findsNothing);
  });
}
