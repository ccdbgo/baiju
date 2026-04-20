import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/pages/note_journal_page.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.now().toUtc();
  final first = NotesTableData(
    id: 'journal-1',
    userId: 'local_user',
    title: '晨间日记',
    content: '今天状态很好',
    noteType: NoteType.diary.value,
    relatedEntityType: 'todo',
    relatedEntityId: 'todo-1',
    isFavorite: false,
    createdAt: now,
    updatedAt: now,
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );
  final second = NotesTableData(
    id: 'journal-2',
    userId: 'local_user',
    title: '晚间日记',
    content: '今晚复盘学习情况',
    noteType: NoteType.diary.value,
    relatedEntityType: null,
    relatedEntityId: null,
    isFavorite: false,
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now.subtract(const Duration(days: 1)),
    deletedAt: null,
    syncStatus: 'synced',
    localVersion: 1,
    remoteVersion: 1,
    lastSyncedAt: now,
    deviceId: 'device-1',
  );

  testWidgets('journal page shows summary and supports related-only filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalNoteListProvider.overrideWith(
            (ref) => Stream<List<NotesTableData>>.value(<NotesTableData>[
              first,
              second,
            ]),
          ),
        ],
        child: const MaterialApp(home: NoteJournalPage()),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('按时间回看日记'), findsOneWidget);
    expect(find.text('当前结果'), findsOneWidget);
    expect(find.text('仅看有关联对象'), findsOneWidget);
    expect(find.text('晨间日记'), findsOneWidget);
    expect(find.text('晚间日记'), findsOneWidget);

    await tester.tap(find.text('仅看有关联对象'));
    await tester.pumpAndSettle();

    expect(find.text('晨间日记'), findsOneWidget);
    expect(find.text('晚间日记'), findsNothing);

    await tester.enterText(find.byType(TextField), '状态');
    await tester.pumpAndSettle();

    expect(find.text('晨间日记'), findsOneWidget);
    expect(find.text('晚间日记'), findsNothing);
  });
}
