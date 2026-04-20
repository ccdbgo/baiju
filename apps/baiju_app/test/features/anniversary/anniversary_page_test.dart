import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/anniversary/presentation/pages/anniversary_page.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final family = AnniversariesTableData(
    id: 'anniversary-1',
    userId: 'local_user',
    title: '妈妈生日',
    baseDate: now,
    calendarType: 'solar',
    remindDaysBefore: 3,
    category: '家庭',
    note: '记得订蛋糕',
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );
  final work = AnniversariesTableData(
    id: 'anniversary-2',
    userId: 'local_user',
    title: '入职纪念日',
    baseDate: now.add(const Duration(days: 10)),
    calendarType: 'solar',
    remindDaysBefore: 7,
    category: '工作',
    note: '回顾成长',
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anniversarySummaryProvider.overrideWith(
            (ref) => Stream<AnniversarySummary>.value(
              const AnniversarySummary(
                total: 2,
                upcoming30Days: 2,
                withReminder: 2,
              ),
            ),
          ),
          anniversaryListProvider.overrideWith(
            (ref) => Stream<List<AnniversariesTableData>>.value(
              <AnniversariesTableData>[family, work],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: AnniversaryPage())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('anniversary page supports category and keyword filtering', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('妈妈生日'), findsOneWidget);
    expect(find.text('入职纪念日'), findsOneWidget);

    await tester.tap(find.text('工作').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('入职纪念日'), findsOneWidget);
    expect(find.text('妈妈生日'), findsNothing);

    await tester.tap(find.text('全部分类'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '蛋糕');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('妈妈生日'), findsOneWidget);
    expect(find.text('入职纪念日'), findsNothing);
  });

  testWidgets('anniversary page exposes sort controls', (tester) async {
    await pumpPage(tester);

    expect(find.text('最近到来'), findsOneWidget);
    expect(find.text('标题 A-Z'), findsOneWidget);
    expect(find.text('最近更新'), findsOneWidget);
  });

  testWidgets('anniversary page shows sprint card shortcuts', (tester) async {
    await pumpPage(tester);

    expect(find.text('近期纪念日冲刺'), findsOneWidget);
    expect(find.text('即将到来'), findsWidgets);
    expect(find.text('30 天内'), findsWidgets);
  });
}
