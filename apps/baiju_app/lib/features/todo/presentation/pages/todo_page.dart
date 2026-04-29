import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum TodoSortOption {
  updatedDesc('最近更新'),
  priorityDesc('优先级'),
  dueSoon('截止时间');

  const TodoSortOption(this.label);

  final String label;
}

class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _pendingTodoIds = <String>{};
  final Set<String> _convertingTodoIds = <String>{};

  TodoPriority _selectedPriority = TodoPriority.notUrgentImportant;
  String? _selectedGoalId;
  TodoSortOption _sortOption = TodoSortOption.updatedDesc;
  DateTime? _dueAt;
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(todoSummaryProvider);
    final todoList = ref.watch(todoListProvider);
    final goalOptions = ref.watch(goalOptionsProvider);
    final selectedFilter = ref.watch(selectedTodoFilterProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('待办', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('管理你的任务清单，支持优先级、截止时间和子任务。', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 18),
          _TodoSummaryCard(summary: summary),
          const SizedBox(height: 16),
          _QuickCreateCard(
            controller: _titleController,
            isCreating: _isCreating,
            dueAt: _dueAt,
            selectedPriority: _selectedPriority,
            goalOptions: goalOptions,
            selectedGoalId: _selectedGoalId,
            onDueAtChanged: (value) => setState(() => _dueAt = value),
            onPriorityChanged: (priority) =>
                setState(() => _selectedPriority = priority),
            onGoalChanged: (goalId) => setState(() => _selectedGoalId = goalId),
            onSubmit: _createTodo,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TodoFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(filter.label),
                selected: filter == selectedFilter,
                onSelected: (_) {
                  ref.read(selectedTodoFilterProvider.notifier).select(filter);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索待办',
            hintText: '按标题搜索',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SelectionChipBar<TodoSortOption>(
            values: TodoSortOption.values,
            selected: _sortOption,
            labelBuilder: (option) => option.label,
            onSelected: (option) => setState(() => _sortOption = option),
          ),
          const SizedBox(height: 16),
          todoList.when(
            data: (todos) {
              if (todos.isEmpty) {
                return _EmptyTodoState(filter: selectedFilter);
              }

              final normalizedSearch = _searchController.text
                  .trim()
                  .toLowerCase();
              final filtered = todos.where((todo) {
                if (normalizedSearch.isEmpty) {
                  return true;
                }
                return todo.title.toLowerCase().contains(normalizedSearch);
              }).toList();

              if (filtered.isEmpty) {
                return const _ErrorCard(message: '当前筛选条件下没有待办。');
              }
              final sorted = filtered.toList()
                ..sort((left, right) {
                  switch (_sortOption) {
                    case TodoSortOption.updatedDesc:
                      return right.updatedAt.compareTo(left.updatedAt);
                    case TodoSortOption.priorityDesc:
                      final priorityDiff = _priorityWeight(
                        right.priority,
                      ).compareTo(_priorityWeight(left.priority));
                      if (priorityDiff != 0) {
                        return priorityDiff;
                      }
                      return right.updatedAt.compareTo(left.updatedAt);
                    case TodoSortOption.dueSoon:
                      final leftDue = left.dueAt ?? DateTime(9999);
                      final rightDue = right.dueAt ?? DateTime(9999);
                      final diff = leftDue.compareTo(rightDue);
                      if (diff != 0) {
                        return diff;
                      }
                      return right.updatedAt.compareTo(left.updatedAt);
                  }
                });

              return Column(
                children: sorted
                    .map(
                      (todo) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TodoListItem(
                          todo: todo,
                          isPending: _pendingTodoIds.contains(todo.id),
                          isConverting: _convertingTodoIds.contains(todo.id),
                          onChanged: (value) =>
                              _toggleTodo(todo, value ?? false),
                          onOpenDetail: () => context.push('/todo/${todo.id}'),
                          onConvert: todo.convertedScheduleId == null
                              ? () => _openConvertSheet(todo)
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                _ErrorCard(message: '待办列表加载失败：$error'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isCreating) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isCreating = true);

    try {
      await ref
          .read(todoActionsProvider)
          .createTodo(
            title: title,
            priority: _selectedPriority,
            dueToday: _dueAt != null,
            goalId: _selectedGoalId,
            dueAt: _dueAt?.toUtc(),
          );

      _titleController.clear();
      if (mounted) {
        setState(() {
          _selectedPriority = TodoPriority.notUrgentImportant;
          _selectedGoalId = null;
          _dueAt = null;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增待办失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _toggleTodo(TodosTableData todo, bool completed) async {
    if (_pendingTodoIds.contains(todo.id)) {
      return;
    }

    setState(() => _pendingTodoIds.add(todo.id));
    try {
      await ref.read(todoActionsProvider).toggleTodoCompletion(todo, completed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新待办状态失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingTodoIds.remove(todo.id));
      }
    }
  }

  Future<void> _openConvertSheet(TodosTableData todo) async {
    var selectedDay = QuickScheduleDay.today;
    var selectedSlot = QuickScheduleSlot.afternoon;
    var selectedDuration = ScheduleDurationOption.oneHour;
    final preferences = ref
        .read(userPreferencesProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const UserPreferences(),
        );
    var selectedReminder = preferences.defaultScheduleReminderOption;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('转成日程', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(todo.title),
                    const SizedBox(height: 16),
                    _ChoiceGroup<QuickScheduleDay>(
                      title: '安排日期',
                      value: selectedDay,
                      values: QuickScheduleDay.values,
                      labelBuilder: (value) => value.label,
                      onChanged: (value) =>
                          setModalState(() => selectedDay = value),
                    ),
                    _ChoiceGroup<QuickScheduleSlot>(
                      title: '开始时间',
                      value: selectedSlot,
                      values: QuickScheduleSlot.values,
                      labelBuilder: (value) => value.label,
                      onChanged: (value) =>
                          setModalState(() => selectedSlot = value),
                    ),
                    _ChoiceGroup<ScheduleDurationOption>(
                      title: '时长',
                      value: selectedDuration,
                      values: ScheduleDurationOption.values,
                      labelBuilder: (value) => value.label,
                      onChanged: (value) =>
                          setModalState(() => selectedDuration = value),
                    ),
                    _ChoiceGroup<ScheduleReminderOption>(
                      title: '提醒时间',
                      value: selectedReminder,
                      values: ScheduleReminderOption.values,
                      labelBuilder: (value) => value.label,
                      onChanged: (value) =>
                          setModalState(() => selectedReminder = value),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('确认转成日程'),
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

    setState(() => _convertingTodoIds.add(todo.id));
    try {
      await ref
          .read(todoActionsProvider)
          .convertTodoToSchedule(
            todo: todo,
            day: selectedDay,
            slot: selectedSlot,
            duration: selectedDuration,
            reminder: selectedReminder,
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已转成日程')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('转日程失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _convertingTodoIds.remove(todo.id));
      }
    }
  }

  int _priorityWeight(String value) {
    switch (TodoPriority.fromValue(value)) {
      case TodoPriority.urgentImportant:
        return 4;
      case TodoPriority.notUrgentImportant:
        return 3;
      case TodoPriority.urgentNotImportant:
        return 2;
      case TodoPriority.notUrgentNotImportant:
        return 1;
    }
  }
}

class _TodoSummaryCard extends StatelessWidget {
  const _TodoSummaryCard({required this.summary});

  final AsyncValue<TodoSummary> summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: summary.when(
          data: (value) => Row(
            children: <Widget>[
              Expanded(
                child: _SummaryItem(
                  label: '总数',
                  value: value.total.toString(),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: '进行中',
                  value: value.active.toString(),
                  color: const Color(0xFF136F63),
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: '今天',
                  value: value.today.toString(),
                  color: const Color(0xFFC06C00),
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  label: '已完成',
                  value: value.completed.toString(),
                  color: const Color(0xFF607D8B),
                ),
              ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text('统计加载失败：$error'),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    );
  }
}

class _QuickCreateCard extends StatelessWidget {
  const _QuickCreateCard({
    required this.controller,
    required this.isCreating,
    required this.dueAt,
    required this.selectedPriority,
    required this.goalOptions,
    required this.selectedGoalId,
    required this.onDueAtChanged,
    required this.onPriorityChanged,
    required this.onGoalChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isCreating;
  final DateTime? dueAt;
  final TodoPriority selectedPriority;
  final AsyncValue<List<GoalsTableData>> goalOptions;
  final String? selectedGoalId;
  final ValueChanged<DateTime?> onDueAtChanged;
  final ValueChanged<TodoPriority> onPriorityChanged;
  final ValueChanged<String?> onGoalChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('快速新增', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !isCreating,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: '输入待办标题，例如：整理本周会议纪要',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TodoPriority.values.map((priority) {
                return ChoiceChip(
                  label: Text(priority.label),
                  selected: priority == selectedPriority,
                  onSelected: isCreating
                      ? null
                      : (_) => onPriorityChanged(priority),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            goalOptions.when(
              data: (goals) => DropdownButtonFormField<String?>(
                initialValue: selectedGoalId,
                decoration: const InputDecoration(
                  labelText: '关联目标',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('不关联目标'),
                  ),
                  ...goals.map(
                    (goal) => DropdownMenuItem<String?>(
                      value: goal.id,
                      child: Text(goal.title),
                    ),
                  ),
                ],
                onChanged: isCreating ? null : onGoalChanged,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => Text('目标加载失败：$error'),
            ),
            const SizedBox(height: 12),
            _DueAtPicker(
              dueAt: dueAt,
              enabled: !isCreating,
              onChanged: onDueAtChanged,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: isCreating ? null : onSubmit,
                icon: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(isCreating ? '保存中' : '新增待办'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.value,
    required this.values,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((item) {
            return ChoiceChip(
              label: Text(labelBuilder(item)),
              selected: item == value,
              onSelected: (_) => onChanged(item),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TodoListItem extends StatelessWidget {
  const _TodoListItem({
    required this.todo,
    required this.isPending,
    required this.isConverting,
    required this.onChanged,
    required this.onOpenDetail,
    this.onConvert,
  });

  final TodosTableData todo;
  final bool isPending;
  final bool isConverting;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDetail;
  final VoidCallback? onConvert;

  @override
  Widget build(BuildContext context) {
    final isCompleted = todo.status == 'completed';
    final theme = Theme.of(context);
    final dueLabel = _formatDueLabel(todo.dueAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Checkbox(
                  value: isCompleted,
                  onChanged: isPending ? null : onChanged,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            todo.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (onConvert != null)
                          TextButton.icon(
                            onPressed: isConverting ? null : onConvert,
                            icon: isConverting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.event_available_outlined),
                            label: Text(isConverting ? '转换中' : '转日程'),
                          )
                        else
                          const Chip(
                            label: Text('已转日程'),
                            avatar: Icon(Icons.check_circle_outline, size: 16),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _MetaChip(
                          label: _priorityLabel(todo.priority),
                          color: _priorityColor(todo.priority),
                          icon: Icons.flag_outlined,
                        ),
                        if (dueLabel != null)
                          _MetaChip(
                            label: dueLabel,
                            color: const Color(0xFFC06C00),
                            icon: Icons.event_outlined,
                          ),
                        if (todo.goalId != null)
                          const _MetaChip(
                            label: '已关联目标',
                            color: Color(0xFF8A5CF6),
                            icon: Icons.flag_outlined,
                          ),
                        _MetaChip(
                          label: isCompleted ? '已完成' : '进行中',
                          color: isCompleted
                              ? const Color(0xFF607D8B)
                              : const Color(0xFF136F63),
                          icon: isCompleted
                              ? Icons.task_alt
                              : Icons.pending_actions_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _priorityLabel(String value) {
    return TodoPriority.fromValue(value).label;
  }

  Color _priorityColor(String value) {
    switch (TodoPriority.fromValue(value)) {
      case TodoPriority.urgentImportant:
        return const Color(0xFFB03A2E); // 红色 - 重要紧急
      case TodoPriority.notUrgentImportant:
        return const Color(0xFF2874A6); // 蓝色 - 重要不紧急
      case TodoPriority.urgentNotImportant:
        return const Color(0xFFC06C00); // 橙色 - 不重要紧急
      case TodoPriority.notUrgentNotImportant:
        return const Color(0xFF5D7A5D); // 绿色 - 不重要不紧急
    }
  }

  String? _formatDueLabel(DateTime? dueAt) {
    if (dueAt == null) {
      return null;
    }

    final localDueAt = dueAt.toLocal();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final tomorrow = start.add(const Duration(days: 1));

    if (!localDueAt.isBefore(start) && localDueAt.isBefore(tomorrow)) {
      return '今天 ${DateFormat('HH:mm').format(localDueAt)}';
    }

    return DateFormat('M月d日 HH:mm').format(localDueAt);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTodoState extends StatelessWidget {
  const _EmptyTodoState({required this.filter});

  final TodoFilter filter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              filter == TodoFilter.all ? '还没有任何待办' : '这个筛选下暂时没有内容',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '先在上方快速新增一条待办，页面会自动从本地数据库刷新。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}

class _DueAtPicker extends StatelessWidget {
  const _DueAtPicker({
    required this.dueAt,
    required this.enabled,
    required this.onChanged,
  });

  final DateTime? dueAt;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: enabled ? () => _pickDateTime(context) : null,
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
            onPressed: enabled ? () => onChanged(null) : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
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
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}
