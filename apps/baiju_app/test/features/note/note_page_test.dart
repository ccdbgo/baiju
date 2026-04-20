import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/pages/note_page.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final relatedNote = NotesTableData(
    id: 'note-1',
    userId: 'local_user',
    title: '会议纪要',
    content: '关联到日程的纪要内容',
    noteType: NoteType.note.value,
    relatedEntityType: 'schedule',
    relatedEntityId: 'schedule-1',
    isFavorite: true,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );
  final plainNote = NotesTableData(
    id: 'note-2',
    userId: 'local_user',
    title: '随手记录',
    content: '没有关联对象',
    noteType: NoteType.memo.value,
    relatedEntityType: null,
    relatedEntityId: null,
    isFavorite: false,
    createdAt: now,
    updatedAt: now.subtract(const Duration(hours: 1)),
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
          noteSummaryProvider.overrideWith(
            (ref) => Stream<NoteSummary>.value(
              const NoteSummary(total: 2, favorites: 1, diaryCount: 1),
            ),
          ),
          noteListProvider.overrideWith(
            (ref) => Stream<List<NotesTableData>>.value(<NotesTableData>[
              relatedNote,
              plainNote,
            ]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: NotePage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('note page supports keyword search and related-only toggle', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('会议纪要'), findsOneWidget);
    expect(find.text('随手记录'), findsOneWidget);

    await tester.tap(find.text('仅看有关联对象的笔记'));
    await tester.pumpAndSettle();

    expect(find.text('会议纪要'), findsOneWidget);
    expect(find.text('随手记录'), findsNothing);

    await tester.tap(find.text('仅看有关联对象的笔记'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '随手');
    await tester.pumpAndSettle();

    expect(find.text('随手记录'), findsOneWidget);
    expect(find.text('会议纪要'), findsNothing);
  });

  testWidgets('note page exposes sort controls', (tester) async {
    await pumpPage(tester);

    expect(find.text('最近更新'), findsOneWidget);
    expect(find.text('标题 A-Z'), findsOneWidget);
    expect(find.text('收藏优先'), findsOneWidget);
  });

  testWidgets('note page shows workbench card', (tester) async {
    await pumpPage(tester);

    expect(find.text('笔记工作台'), findsOneWidget);
    expect(find.text('日记时间轴'), findsWidgets);
    expect(find.text('类型：全部'), findsOneWidget);
  });
}
