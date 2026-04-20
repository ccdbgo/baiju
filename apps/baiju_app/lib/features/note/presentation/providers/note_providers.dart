import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/infrastructure/note_repository.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final workspace = ref.watch(currentUserWorkspaceProvider);
  return NoteRepository(database, workspace: workspace);
});

final selectedNoteFilterProvider =
    NotifierProvider<SelectedNoteFilterNotifier, NoteFilter>(
      SelectedNoteFilterNotifier.new,
    );

final noteListProvider = StreamProvider.autoDispose<List<NotesTableData>>((
  ref,
) {
  final repository = ref.watch(noteRepositoryProvider);
  final filter = ref.watch(selectedNoteFilterProvider);
  return repository.watchNotes(filter);
});

final noteDetailProvider = StreamProvider.family
    .autoDispose<NotesTableData?, String>((ref, noteId) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      return (database.select(database.notesTable)..where(
            (tbl) =>
                tbl.deletedAt.isNull() &
                tbl.userId.equals(workspace.userId) &
                tbl.id.equals(noteId),
          ))
          .watchSingleOrNull();
    });

final relatedNoteListProvider = StreamProvider.family
    .autoDispose<List<NotesTableData>, NoteRelationTarget>((ref, target) {
      final database = ref.watch(appDatabaseProvider);
      final workspace = ref.watch(currentUserWorkspaceProvider);
      final query = database.select(database.notesTable)
        ..where(
          (tbl) =>
              tbl.deletedAt.isNull() &
              tbl.userId.equals(workspace.userId) &
              tbl.relatedEntityType.equals(target.entityType) &
              tbl.relatedEntityId.equals(target.entityId),
        )
        ..orderBy(<OrderingTerm Function($NotesTableTable)>[
          (tbl) => OrderingTerm.desc(tbl.updatedAt),
        ]);
      return query.watch();
    });

final noteSummaryProvider = StreamProvider.autoDispose<NoteSummary>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return repository.watchNotes(NoteFilter.all).map((items) {
    return NoteSummary(
      total: items.length,
      favorites: items.where((item) => item.isFavorite).length,
      diaryCount: items
          .where((item) => item.noteType == NoteType.diary.value)
          .length,
    );
  });
});

final recentNoteListProvider = StreamProvider.autoDispose<List<NotesTableData>>(
  (ref) {
    final repository = ref.watch(noteRepositoryProvider);
    return repository
        .watchNotes(NoteFilter.all)
        .map((items) => items.take(4).toList());
  },
);

final journalNoteListProvider =
    StreamProvider.autoDispose<List<NotesTableData>>((ref) {
      final repository = ref.watch(noteRepositoryProvider);
      return repository.watchNotes(NoteFilter.diary);
    });

final noteActionsProvider = Provider<NoteActions>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return NoteActions(repository);
});

class NoteActions {
  const NoteActions(this._repository);

  final NoteRepository _repository;

  Future<void> createNote({
    required String title,
    required String content,
    required NoteType noteType,
    required bool isFavorite,
    String? relatedEntityType,
    String? relatedEntityId,
  }) {
    return _repository.createNote(
      title: title,
      content: content,
      noteType: noteType,
      isFavorite: isFavorite,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
    );
  }

  Future<void> updateNote({
    required NotesTableData note,
    required String title,
    required String content,
    required NoteType noteType,
    required bool isFavorite,
    String? relatedEntityType,
    String? relatedEntityId,
  }) {
    return _repository.updateNote(
      note: note,
      title: title,
      content: content,
      noteType: noteType,
      isFavorite: isFavorite,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
    );
  }

  Future<void> setFavorite(NotesTableData note, bool favorite) {
    return _repository.setFavorite(note, favorite);
  }

  Future<void> deleteNote(NotesTableData note) {
    return _repository.deleteNote(note);
  }
}

class SelectedNoteFilterNotifier extends Notifier<NoteFilter> {
  @override
  NoteFilter build() {
    return NoteFilter.all;
  }

  void select(NoteFilter filter) {
    state = filter;
  }
}
