import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NoteDetailPage extends ConsumerWidget {
  const NoteDetailPage({required this.noteId, super.key});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteDetailProvider(noteId));

    return Scaffold(
      appBar: AppBar(title: const Text('笔记详情')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: note.when(
          data: (value) {
            if (value == null) {
              return const Center(child: Text('笔记不存在或已删除'));
            }
            final title = (value.title == null || value.title!.trim().isEmpty)
                ? '无标题笔记'
                : value.title!;
            final relationRoute = _relationRoute(value);

            return ListView(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openEditNoteSheet(context, ref, value),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: '类型',
                  value: NoteType.fromValue(value.noteType).label,
                ),
                _DetailRow(
                  label: '更新时间',
                  value: DateFormat(
                    'yyyy年M月d日 HH:mm',
                  ).format(value.updatedAt.toLocal()),
                ),
                if (value.relatedEntityType != null &&
                    value.relatedEntityId != null) ...<Widget>[
                  _LinkedObjectTile(
                    label: '关联对象',
                    title: _relationLabel(value),
                    onTap: relationRoute == null
                        ? null
                        : () => context.push(relationRoute),
                  ),
                  const SizedBox(height: 12),
                ],
                _DetailRow(label: '内容', value: value.content),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _toggleFavorite(context, ref, value),
                      icon: Icon(
                        value.isFavorite
                            ? Icons.star_outline
                            : Icons.star_border_outlined,
                      ),
                      label: Text(value.isFavorite ? '取消收藏' : '加入收藏'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deleteNote(context, ref, value),
                      icon: const Icon(Icons.delete_outline),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      label: const Text('删除'),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('加载失败：$error')),
        ),
      ),
    );
  }

  Future<void> _openEditNoteSheet(
    BuildContext context,
    WidgetRef ref,
    NotesTableData note,
  ) async {
    final result = await showNoteEditorSheet(
      context,
      title: '编辑笔记',
      confirmLabel: '保存修改',
      initialTitle: note.title ?? '',
      initialContent: note.content,
      initialType: NoteType.fromValue(note.noteType),
      initialFavorite: note.isFavorite,
    );
    if (result == null) {
      return;
    }

    await ref
        .read(noteActionsProvider)
        .updateNote(
          note: note,
          title: result.title,
          content: result.content,
          noteType: result.noteType,
          isFavorite: result.isFavorite,
          relatedEntityType: note.relatedEntityType,
          relatedEntityId: note.relatedEntityId,
        );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    NotesTableData note,
  ) async {
    await ref.read(noteActionsProvider).setFavorite(note, !note.isFavorite);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(note.isFavorite ? '已取消收藏' : '已加入收藏')),
    );
  }

  Future<void> _deleteNote(
    BuildContext context,
    WidgetRef ref,
    NotesTableData note,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除这条笔记？'),
          content: const Text('删除后会从笔记列表中移除，但时间线仍会保留操作记录。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(noteActionsProvider).deleteNote(note);
    if (!context.mounted) {
      return;
    }
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('笔记已删除')));
  }

  String? _relationRoute(NotesTableData note) {
    if (note.relatedEntityType == null || note.relatedEntityId == null) {
      return null;
    }
    return switch (note.relatedEntityType) {
      'todo' => '/todo/${note.relatedEntityId}',
      'schedule' => '/schedule/${note.relatedEntityId}',
      'habit' => '/habit/${note.relatedEntityId}',
      'goal' => '/goal/${note.relatedEntityId}',
      'anniversary' => '/anniversary/${note.relatedEntityId}',
      _ => null,
    };
  }

  String _relationLabel(NotesTableData note) {
    switch (note.relatedEntityType) {
      case 'todo':
        return '关联待办';
      case 'schedule':
        return '关联日程';
      case 'habit':
        return '关联习惯';
      case 'goal':
        return '关联目标';
      case 'anniversary':
        return '关联纪念日';
      default:
        return '关联对象';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _LinkedObjectTile extends StatelessWidget {
  const _LinkedObjectTile({
    required this.label,
    required this.title,
    required this.onTap,
  });

  final String label;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        leading: const Icon(Icons.link_outlined),
        title: Text(title),
        subtitle: Text(label),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}
