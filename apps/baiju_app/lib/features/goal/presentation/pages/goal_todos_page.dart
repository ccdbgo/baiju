import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum GoalTodoFilter {
  all('全部'),
  active('进行中'),
  completed('已完成');

  const GoalTodoFilter(this.label);

  final String label;
}

class GoalTodosPage extends ConsumerStatefulWidget {
  const GoalTodosPage({required this.goalId, super.key});

  final String goalId;

  @override
  ConsumerState<GoalTodosPage> createState() => _GoalTodosPageState();
}

class _GoalTodosPageState extends ConsumerState<GoalTodosPage> {
  GoalTodoFilter _filter = GoalTodoFilter.all;

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(goalTodoDetailsProvider(widget.goalId));

    return Scaffold(
      appBar: AppBar(title: const Text('关联待办')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GoalTodoFilter.values.map((item) {
              return ChoiceChip(
                label: Text(item.label),
                selected: item == _filter,
                onSelected: (_) => setState(() => _filter = item),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          todos.when(
            data: (items) {
              final filtered = switch (_filter) {
                GoalTodoFilter.all => items,
                GoalTodoFilter.active =>
                  items.where((item) => item.status != 'completed').toList(),
                GoalTodoFilter.completed =>
                  items.where((item) => item.status == 'completed').toList(),
              };

              if (filtered.isEmpty) {
                return const _EmptyState(text: '这个目标下还没有关联待办');
              }

              return Column(
                children: filtered
                    .map(
                      (todo) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openEditTodoSheet(todo),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          todo.title,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            context.push('/todo/${todo.id}'),
                                        child: const Text('详情'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    todo.dueAt == null
                                        ? '无截止时间'
                                        : '截止 ${DateFormat('M月d日 HH:mm').format(todo.dueAt!.toLocal())}',
                                  ),
                                  const SizedBox(height: 8),
                                  Chip(
                                    label: Text(
                                      TodoPriority.fromValue(
                                        todo.priority,
                                      ).label,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text('加载失败：$error'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditTodoSheet(TodosTableData todo) async {
    final titleController = TextEditingController(text: todo.title);
    var priority = TodoPriority.fromValue(todo.priority);
    var dueToday = todo.dueAt != null;

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                      SwitchListTile(
                        value: dueToday,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('今天处理'),
                        onChanged: (value) =>
                            setModalState(() => dueToday = value),
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

      if (confirmed != true || !mounted) {
        return;
      }

      final dueAt = dueToday ? DateTime.now().toUtc() : null;
      await ref
          .read(todoActionsProvider)
          .updateTodo(
            todo: todo,
            title: titleController.text.trim(),
            priority: priority,
            dueAt: dueAt,
          );
    } finally {
      titleController.dispose();
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text)),
      ),
    );
  }
}
