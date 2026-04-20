import 'dart:convert';

import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class NoteRepository {
  NoteRepository(this._database, {UserWorkspace? workspace, Uuid? uuid})
    : _workspace = workspace ?? const UserWorkspace.local(),
      _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final UserWorkspace _workspace;
  final Uuid _uuid;

  Stream<List<NotesTableData>> watchNotes(NoteFilter filter) {
    final query = _database.select(_database.notesTable)
      ..where(
        (tbl) => tbl.deletedAt.isNull() & tbl.userId.equals(_workspace.userId),
      )
      ..orderBy(<OrderingTerm Function($NotesTableTable)>[
        (tbl) => OrderingTerm.desc(tbl.isFavorite),
        (tbl) => OrderingTerm.desc(tbl.updatedAt),
      ]);

    switch (filter) {
      case NoteFilter.all:
        break;
      case NoteFilter.favorites:
        query.where((tbl) => tbl.isFavorite.equals(true));
      case NoteFilter.note:
        query.where((tbl) => tbl.noteType.equals(NoteType.note.value));
      case NoteFilter.diary:
        query.where((tbl) => tbl.noteType.equals(NoteType.diary.value));
      case NoteFilter.memo:
        query.where((tbl) => tbl.noteType.equals(NoteType.memo.value));
    }

    return query.watch();
  }

  Future<void> createNote({
    required String title,
    required String content,
    required NoteType noteType,
    required bool isFavorite,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    final now = DateTime.now().toUtc();
    final noteId = _uuid.v4();
    final normalizedTitle = _emptyToNull(title) ?? _fallbackTitle(content);

    await _database.transaction(() async {
      await _database
          .into(_database.notesTable)
          .insert(
            NotesTableCompanion.insert(
              id: noteId,
              userId: _workspace.userId,
              title: Value(normalizedTitle),
              content: content.trim(),
              noteType: Value(noteType.value),
              relatedEntityType: Value(_emptyToNull(relatedEntityType)),
              relatedEntityId: Value(_emptyToNull(relatedEntityId)),
              isFavorite: Value(isFavorite),
              createdAt: Value(now),
              updatedAt: Value(now),
              syncStatus: const Value('pending_create'),
              localVersion: const Value(1),
              deviceId: Value(_workspace.deviceId),
            ),
          );

      await _enqueueSync(
        entityId: noteId,
        operation: 'create',
        payload: <String, Object?>{
          'id': noteId,
          'title': normalizedTitle,
          'content': content.trim(),
          'note_type': noteType.value,
          'related_entity_type': _emptyToNull(relatedEntityType),
          'related_entity_id': _emptyToNull(relatedEntityId),
          'is_favorite': isFavorite,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: noteId,
        action: 'created',
        title: normalizedTitle,
        summary: '新增了一条笔记',
        occurredAt: now,
      );
    });
  }

  Future<void> updateNote({
    required NotesTableData note,
    required String title,
    required String content,
    required NoteType noteType,
    required bool isFavorite,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    final now = DateTime.now().toUtc();
    final nextVersion = note.localVersion + 1;
    final normalizedTitle = _emptyToNull(title) ?? _fallbackTitle(content);

    await _database.transaction(() async {
      await (_database.update(_database.notesTable)..where(
            (tbl) =>
                tbl.id.equals(note.id) & tbl.userId.equals(_workspace.userId),
          ))
          .write(
            NotesTableCompanion(
              title: Value(normalizedTitle),
              content: Value(content.trim()),
              noteType: Value(noteType.value),
              relatedEntityType: Value(
                _emptyToNull(relatedEntityType) ?? note.relatedEntityType,
              ),
              relatedEntityId: Value(
                _emptyToNull(relatedEntityId) ?? note.relatedEntityId,
              ),
              isFavorite: Value(isFavorite),
              updatedAt: Value(now),
              syncStatus: const Value('pending_update'),
              localVersion: Value(nextVersion),
              deviceId: Value(_workspace.deviceId),
            ),
          );

      await _enqueueSync(
        entityId: note.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': note.id,
          'title': normalizedTitle,
          'content': content.trim(),
          'note_type': noteType.value,
          'related_entity_type':
              _emptyToNull(relatedEntityType) ?? note.relatedEntityType,
          'related_entity_id':
              _emptyToNull(relatedEntityId) ?? note.relatedEntityId,
          'is_favorite': isFavorite,
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: note.id,
        action: 'updated',
        title: normalizedTitle,
        summary: '更新了一条笔记',
        occurredAt: now,
      );
    });
  }

  Future<void> setFavorite(NotesTableData note, bool favorite) async {
    final now = DateTime.now().toUtc();
    final nextVersion = note.localVersion + 1;
    final title = note.title ?? _fallbackTitle(note.content);

    await _database.transaction(() async {
      await (_database.update(_database.notesTable)..where(
            (tbl) =>
                tbl.id.equals(note.id) & tbl.userId.equals(_workspace.userId),
          ))
          .write(
            NotesTableCompanion(
              isFavorite: Value(favorite),
              updatedAt: Value(now),
              syncStatus: const Value('pending_update'),
              localVersion: Value(nextVersion),
              deviceId: Value(_workspace.deviceId),
            ),
          );

      await _enqueueSync(
        entityId: note.id,
        operation: 'update',
        payload: <String, Object?>{
          'id': note.id,
          'is_favorite': favorite,
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: note.id,
        action: favorite ? 'favorited' : 'unfavorited',
        title: title,
        summary: favorite ? '收藏了一条笔记' : '取消收藏了一条笔记',
        occurredAt: now,
      );
    });
  }

  Future<void> deleteNote(NotesTableData note) async {
    final now = DateTime.now().toUtc();
    final nextVersion = note.localVersion + 1;
    final title = note.title ?? _fallbackTitle(note.content);

    await _database.transaction(() async {
      await (_database.update(_database.notesTable)..where(
            (tbl) =>
                tbl.id.equals(note.id) & tbl.userId.equals(_workspace.userId),
          ))
          .write(
            NotesTableCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              syncStatus: const Value('pending_delete'),
              localVersion: Value(nextVersion),
              deviceId: Value(_workspace.deviceId),
            ),
          );

      await _enqueueSync(
        entityId: note.id,
        operation: 'delete',
        payload: <String, Object?>{
          'id': note.id,
          'deleted_at': now.toIso8601String(),
          'local_version': nextVersion,
          'updated_at': now.toIso8601String(),
        },
      );

      await _appendTimelineEvent(
        sourceEntityId: note.id,
        action: 'deleted',
        title: title,
        summary: '删除了一条笔记',
        occurredAt: now,
      );
    });
  }

  Future<void> _enqueueSync({
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    return _database
        .into(_database.syncQueueTable)
        .insert(
          SyncQueueTableCompanion.insert(
            id: _uuid.v4(),
            userId: Value(_workspace.userId),
            entityType: 'note',
            entityId: entityId,
            operation: operation,
            payloadJson: jsonEncode(payload),
          ),
        );
  }

  Future<void> _appendTimelineEvent({
    required String sourceEntityId,
    required String action,
    required String title,
    required String summary,
    required DateTime occurredAt,
  }) {
    return _database
        .into(_database.timelineEventsTable)
        .insert(
          TimelineEventsTableCompanion.insert(
            id: _uuid.v4(),
            userId: _workspace.userId,
            eventType: 'note',
            eventAction: action,
            sourceEntityId: sourceEntityId,
            sourceEntityType: 'note',
            occurredAt: occurredAt,
            title: title,
            summary: Value(summary),
            payloadJson: Value(
              jsonEncode(<String, Object?>{'action': action, 'title': title}),
            ),
            createdAt: Value(occurredAt),
            updatedAt: Value(occurredAt),
            syncStatus: const Value('pending_create'),
            localVersion: const Value(1),
            deviceId: Value(_workspace.deviceId),
          ),
        );
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _fallbackTitle(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '无标题笔记';
    }
    final firstLine = trimmed.split('\n').first.trim();
    return firstLine.isEmpty ? '无标题笔记' : firstLine;
  }
}
