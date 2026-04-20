import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/infrastructure/note_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late NoteRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = NoteRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'createNote writes note relation, sync queue and timeline event',
    () async {
      await repository.createNote(
        title: '今日复盘',
        content: '推进待办并完成回顾',
        noteType: NoteType.diary,
        isFavorite: true,
        relatedEntityType: 'todo',
        relatedEntityId: 'todo-001',
      );

      final notes = await database.select(database.notesTable).get();
      final syncQueue = await database.select(database.syncQueueTable).get();
      final timelineEvents = await database
          .select(database.timelineEventsTable)
          .get();

      expect(notes, hasLength(1));
      expect(notes.single.noteType, NoteType.diary.value);
      expect(notes.single.isFavorite, isTrue);
      expect(notes.single.relatedEntityType, 'todo');
      expect(notes.single.relatedEntityId, 'todo-001');
      expect(syncQueue.single.entityType, 'note');
      expect(timelineEvents.single.eventType, 'note');
      expect(timelineEvents.single.eventAction, 'created');
    },
  );

  test('watchNotes filters favorites and diary streams correctly', () async {
    await repository.createNote(
      title: '工作记录',
      content: '普通笔记',
      noteType: NoteType.note,
      isFavorite: false,
    );
    await repository.createNote(
      title: '晚间日记',
      content: '今天状态不错',
      noteType: NoteType.diary,
      isFavorite: true,
    );

    final favorites = await repository.watchNotes(NoteFilter.favorites).first;
    final diaries = await repository.watchNotes(NoteFilter.diary).first;

    expect(favorites, hasLength(1));
    expect(favorites.single.title, '晚间日记');
    expect(diaries, hasLength(1));
    expect(diaries.single.noteType, NoteType.diary.value);
  });

  test(
    'updateNote and setFavorite keep relation fields and write tracking',
    () async {
      await repository.createNote(
        title: '目标拆解',
        content: '拆成三个阶段',
        noteType: NoteType.memo,
        isFavorite: false,
        relatedEntityType: 'goal',
        relatedEntityId: 'goal-001',
      );

      final created = (await database.select(database.notesTable).get()).single;

      await repository.updateNote(
        note: created,
        title: '目标拆解 v2',
        content: '拆成四个阶段',
        noteType: NoteType.memo,
        isFavorite: false,
      );

      var updated = (await database.select(database.notesTable).get()).single;
      expect(updated.relatedEntityType, 'goal');
      expect(updated.relatedEntityId, 'goal-001');

      await repository.setFavorite(updated, true);

      updated = (await database.select(database.notesTable).get()).single;
      final timelineEvents = await database
          .select(database.timelineEventsTable)
          .get();

      expect(updated.isFavorite, isTrue);
      expect(
        timelineEvents.any((event) => event.eventAction == 'updated'),
        isTrue,
      );
      expect(
        timelineEvents.any((event) => event.eventAction == 'favorited'),
        isTrue,
      );
    },
  );
}
