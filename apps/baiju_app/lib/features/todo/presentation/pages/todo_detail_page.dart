import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_editor_sheet.dart';
import 'package:baiju_app/features/note/presentation/widgets/related_notes_section.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TodoDetailPage extends ConsumerStatefulWidget {
  const TodoDetailPage({required this.todoId, super.key});

  final String todoId;

  @override
  ConsumerState<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends ConsumerState<TodoDetailPage> {
  final TextEditingController _subtaskController = TextEditingController();
  final Set<String> _pendingSubtaskIds = <String>{};
  bool _isCreatingSubtask = false;

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todo = ref.watch(todoDetailProvider(widget.todoId));

    return Scaffold(
      appBar: AppBar(title: const Text('待办详情')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: todo.when(
          data: (value) {
            if (value == null) {
              return const Center(child: Text('待办不存在或已删除'));
            }
            final linkedGoal = value.goalId == null
                ? null
                : ref.watch(goalDetailProvider(value.goalId!));
            final linkedSchedule = value.convertedScheduleId == null
                ? null
                : ref.watch(scheduleDetailProvider(value.convertedScheduleId!));
            final relatedNotes = ref.watch(
              relatedNoteListProvider(
                NoteRelationTarget(entityType: 'todo', entityId: value.id),
              ),
            );
            final subtasks = ref.watch(todoSubtaskListProvider(value.id));

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
                      onPressed: () => _openEditTodoSheet(value),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailRow(label: '优先级', value: value.priority),
                _DetailRow(label: '状态', value: value.status),
                if (value.dueAt != null)
                  _DetailRow(
                    label: '截止时间',
                    value: DateFormat(
                      'yyyy年M月d日 HH:mm',
                    ).format(value.dueAt!.toLocal()),
                  ),
                const SizedBox(height: 8),
                _SubtaskSection(
                  subtasks: subtasks,
                  controller: _subtaskController,
                  isCreating: _isCreatingSubtask,
                  pendingIds: _pendingSubtaskIds,
                  onCreate: () => _createSubtask(value.id),
                  onToggle: _toggleSubtask,
                  onDelete: _deleteSubtask,
                ),
                const SizedBox(height: 16),
                if (linkedGoal != null || linkedSchedule != null) ...<Widget>[
                  Text('关联对象', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (linkedGoal != null)
                    linkedGoal.when(
                      data: (goal) => _LinkedObjectTile(
                        label: '关联目标',
                        title: goal?.title ?? value.goalId!,
                        icon: Icons.flag_outlined,
                        onTap: goal == null
                            ? null
                            : () => context.push('/goal/${goal.id}'),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) => Text('关联目标加载失败：$error'),
                    ),
                  if (linkedGoal != null && linkedSchedule != null)
                    const SizedBox(height: 10),
                  if (linkedSchedule != null)
                    linkedSchedule.when(
                      data: (schedule) => _LinkedObjectTile(
                        label: '转换后的日程',
                        title: schedule?.title ?? value.convertedScheduleId!,
                        icon: Icons.event_outlined,
                        onTap: schedule == null
                            ? null
                            : () => context.push('/schedule/${schedule.id}'),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) => Text('关联日程加载失败：$error'),
                    ),
                  const SizedBox(height: 12),
                ],
                RelatedNotesSection(
                  relatedNotes: relatedNotes,
                  onCreate: () => _createRelatedNote(value),
                  onOpenNote: (note) => context.push('/note/${note.id}'),
                ),
                const SizedBox(height: 12),
                Text('状态操作', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (value.status != 'archived')
                      OutlinedButton.icon(
                        onPressed: () => _archiveTodo(value),
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('归档'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _deleteTodo(value),
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

  Future<void> _createSubtask(String todoId) async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty || _isCreatingSubtask) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isCreatingSubtask = true);
    try {
      await ref
          .read(todoActionsProvider)
          .createTodoSubtask(todoId: todoId, title: title);
      _subtaskController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增子任务失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingSubtask = false);
      }
    }
  }

  Future<void> _toggleSubtask(TodoSubtasksTableData subtask, bool completed) async {
    if (_pendingSubtaskIds.contains(subtask.id)) {
      return;
    }

    setState(() => _pendingSubtaskIds.add(subtask.id));
    try {
      await ref
          .read(todoActionsProvider)
          .toggleTodoSubtaskCompletion(subtask, completed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新子任务状态失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingSubtaskIds.remove(subtask.id));
      }
    }
  }

  Future<void> _deleteSubtask(TodoSubtasksTableData subtask) async {
    if (_pendingSubtaskIds.contains(subtask.id)) {
      return;
    }

    setState(() => _pendingSubtaskIds.add(subtask.id));
    try {
      await ref.read(todoActionsProvider).deleteTodoSubtask(subtask);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除子任务失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingSubtaskIds.remove(subtask.id));
      }
    }
  }

  Future<void> _openEditTodoSheet(TodosTableData todo) async {
    final titleController = TextEditingController(text: todo.title);
    var priority = TodoPriority.fromValue(todo.priority);
    var dueAt = todo.dueAt?.toLocal();

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
                  padding: EdgeInsets.fromLTRB(
                    20, 8, 20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '编辑待办',
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TodoPriority.values.map((value) {
                          return ChoiceChip(
                            label: Text(value.label),
                            selected: value == priority,
                            onSelected: (_) =>
                                setModalState(() => priority = value),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final initial = dueAt ?? now;
                              final date = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(now.year - 1),
                                lastDate: DateTime(now.year + 5),
                              );
                              if (date == null || !context.mounted) return;
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(initial),
                              );
                              if (time == null) return;
                              setModalState(() => dueAt = DateTime(
                                date.year, date.month, date.day,
                                time.hour, time.minute,
                              ));
                            },
                            icon: const Icon(Icons.event_outlined, size: 16),
                            label: Text(
                              dueAt == null
                                  ? '设置截止时间'
                                  : DateFormat('M月d日 HH:mm').format(dueAt!),
                            ),
                          ),
                          if (dueAt != null) ...<Widget>[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              tooltip: '清除截止时间',
                              onPressed: () => setModalState(() => dueAt = null),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('保存修改'),
                        ),
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
          .read(todoActionsProvider)
          .updateTodo(
            todo: todo,
            title: titleController.text.trim(),
            priority: priority,
            dueAt: dueAt?.toUtc(),
          );
    } finally {
      titleController.dispose();
    }
  }

  Future<void> _archiveTodo(TodosTableData todo) async {
    final confirmed = await _confirmAction(
      title: '归档这条待办？',
      message: '归档后它会从进行中的待办列表中移出。',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(todoActionsProvider).archiveTodo(todo);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('待办已归档')));
  }

  Future<void> _createRelatedNote(TodosTableData todo) async {
    final result = await showNoteEditorSheet(
      context,
      title: '新增关联笔记',
      confirmLabel: '保存笔记',
      initialTitle: todo.title,
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
          relatedEntityType: 'todo',
          relatedEntityId: todo.id,
        );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关联笔记已创建')));
    }
  }

  Future<void> _deleteTodo(TodosTableData todo) async {
    final confirmed = await _confirmAction(
      title: '删除这条待办？',
      message: '删除后将从待办列表移除，但时间线仍会保留操作记录。',
      confirmLabel: '删除',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(todoActionsProvider).deleteTodo(todo);
    if (!mounted) {
      return;
    }
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('待办已删除')));
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    String confirmLabel = '确认',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }
}

class _SubtaskSection extends StatelessWidget {
  const _SubtaskSection({
    required this.subtasks,
    required this.controller,
    required this.isCreating,
    required this.pendingIds,
    required this.onCreate,
    required this.onToggle,
    required this.onDelete,
  });

  final AsyncValue<List<TodoSubtasksTableData>> subtasks;
  final TextEditingController controller;
  final bool isCreating;
  final Set<String> pendingIds;
  final VoidCallback onCreate;
  final void Function(TodoSubtasksTableData subtask, bool completed) onToggle;
  final void Function(TodoSubtasksTableData subtask) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: subtasks.when(
          data: (items) {
            final completed = items.where((item) => item.isCompleted).length;
            final total = items.length;
            final progress = total == 0 ? 0.0 : completed / total;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('子任务', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '已完成 $completed / $total',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: controller,
                        enabled: !isCreating,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onCreate(),
                        decoration: const InputDecoration(
                          hintText: '快速新增子任务',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: isCreating ? null : onCreate,
                      icon: isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Text('还没有子任务，先拆一条最小行动。')
                else
                  ...items.map((subtask) {
                    final isPending = pendingIds.contains(subtask.id);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: subtask.isCompleted,
                      onChanged: isPending
                          ? null
                          : (value) => onToggle(subtask, value ?? false),
                      title: Text(
                        subtask.title,
                        style: TextStyle(
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      secondary: IconButton(
                        onPressed: isPending ? null : () => onDelete(subtask),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除子任务',
                      ),
                    );
                  }),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text('子任务加载失败：$error'),
        ),
      ),
    );
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

class _LinkedObjectTile extends StatelessWidget {
  const _LinkedObjectTile({
    required this.label,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(label),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      ),
    );
  }
}
