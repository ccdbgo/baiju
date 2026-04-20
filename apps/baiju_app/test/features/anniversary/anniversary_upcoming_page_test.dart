import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/presentation/pages/anniversary_upcoming_page.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final near = AnniversariesTableData(
    id: 'anniversary-near',
    userId: 'local_user',
    title: '近期纪念日',
    baseDate: now.add(const Duration(days: 3)),
    calendarType: 'solar',
    remindDaysBefore: 3,
    category: '家庭',
    note: '需要准备礼物',
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );
  final far = AnniversariesTableData(
    id: 'anniversary-far',
    userId: 'local_user',
    title: '远期纪念日',
    baseDate: now.add(const Duration(days: 20)),
    calendarType: 'solar',
    remindDaysBefore: 7,
    category: '工作',
    note: null,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );

  testWidgets('upcoming page renders summary and supports search/filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anniversaryListProvider.overrideWith(
            (ref) => Stream<List<AnniversariesTableData>>.value(
              <AnniversariesTableData>[near, far],
            ),
          ),
        ],
        child: const MaterialApp(home: AnniversaryUpcomingPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('近期纪念日冲刺'), findsOneWidget);
    expect(find.text('当前结果'), findsOneWidget);
    expect(find.text('搜索纪念日'), findsOneWidget);
    expect(find.text('近期纪念日'), findsOneWidget);
    expect(find.text('远期纪念日'), findsOneWidget);

    await tester.tap(find.text('7 天内'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('近期纪念日'), findsOneWidget);
    expect(find.text('远期纪念日'), findsNothing);

    await tester.enterText(find.byType(TextField), '礼物');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('近期纪念日'), findsOneWidget);
    expect(find.text('远期纪念日'), findsNothing);
  });
}
