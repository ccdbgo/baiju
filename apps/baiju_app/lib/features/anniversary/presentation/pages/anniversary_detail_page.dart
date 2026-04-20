import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_editor_sheet.dart';
import 'package:baiju_app/features/note/presentation/widgets/related_notes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AnniversaryDetailPage extends ConsumerWidget {
  const AnniversaryDetailPage({required this.anniversaryId, super.key});

  final String anniversaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anniversary = ref.watch(anniversaryDetailProvider(anniversaryId));

    return Scaffold(
      appBar: AppBar(title: const Text('纪念日详情')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: anniversary.when(
          data: (value) {
            if (value == null) {
              return const Center(child: Text('纪念日不存在或已删除'));
            }
            final days = daysUntilNextAnniversary(value.baseDate);
            final relatedNotes = ref.watch(
              relatedNoteListProvider(
                NoteRelationTarget(
                  entityType: 'anniversary',
                  entityId: value.id,
                ),
              ),
            );

            return ListView(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        value.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          _openEditAnniversarySheet(context, ref, value),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: '日期',
                  value: DateFormat(
                    'yyyy年M月d日',
                  ).format(value.baseDate.toLocal()),
                ),
                _DetailRow(label: '下次到来', value: days == 0 ? '今天' : '$days 天后'),
                _DetailRow(
                  label: '提醒',
                  value: AnniversaryReminderOption.fromDays(
                    value.remindDaysBefore,
                  ).label,
                ),
                if (value.category != null)
                  _DetailRow(label: '分类', value: value.category!),
                if (value.note != null && value.note!.isNotEmpty)
                  _DetailRow(label: '备注', value: value.note!),
                const SizedBox(height: 16),
                RelatedNotesSection(
                  relatedNotes: relatedNotes,
                  onCreate: () => _createRelatedNote(context, ref, value),
                  onOpenNote: (note) => context.push('/note/${note.id}'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _deleteAnniversary(context, ref, value),
                  icon: const Icon(Icons.delete_outline),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  label: const Text('删除'),
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

  Future<void> _openEditAnniversarySheet(
    BuildContext context,
    WidgetRef ref,
    AnniversariesTableData anniversary,
  ) async {
    final titleController = TextEditingController(text: anniversary.title);
    final categoryController = TextEditingController(
      text: anniversary.category ?? '',
    );
    final noteController = TextEditingController(text: anniversary.note ?? '');
    var selectedDate = anniversary.baseDate.toLocal();
    var selectedReminder = AnniversaryReminderOption.fromDays(
      anniversary.remindDaysBefore,
    );

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      Text(
                        '编辑纪念日',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '标题',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: categoryController,
                              decoration: const InputDecoration(
                                labelText: '分类',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(1970),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              DateFormat('M月d日').format(selectedDate),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AnniversaryReminderOption.values.map((
                          option,
                        ) {
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: option == selectedReminder,
                            onSelected: (_) =>
                                setModalState(() => selectedReminder = option),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('保存修改'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      await ref
          .read(anniversaryActionsProvider)
          .updateAnniversary(
            anniversary: anniversary,
            title: titleController.text.trim(),
            baseDate: selectedDate,
            reminder: selectedReminder,
            category: categoryController.text.trim(),
            note: noteController.text.trim(),
          );
    } finally {
      titleController.dispose();
      categoryController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _deleteAnniversary(
    BuildContext context,
    WidgetRef ref,
    AnniversariesTableData anniversary,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除这个纪念日？'),
          content: const Text('删除后会从纪念日列表中移除，但时间线仍会保留记录。'),
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

    await ref.read(anniversaryActionsProvider).deleteAnniversary(anniversary);
    if (!context.mounted) {
      return;
    }
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('纪念日已删除')));
  }

  Future<void> _createRelatedNote(
    BuildContext context,
    WidgetRef ref,
    AnniversariesTableData anniversary,
  ) async {
    final result = await showNoteEditorSheet(
      context,
      title: '新增关联笔记',
      confirmLabel: '保存笔记',
      initialTitle: anniversary.title,
    );
    if (result == null) {
      return;
    }

    await ref
        .read(noteActionsProvider)
        .createNote(
          title: result.title,
          content: result.content,
          noteType: result.noteType,
          isFavorite: result.isFavorite,
          relatedEntityType: 'anniversary',
          relatedEntityId: anniversary.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关联笔记已创建')));
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
          Text(value),
        ],
      ),
    );
  }
}
