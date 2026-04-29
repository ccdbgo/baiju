import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum GoalViewMode {
  day('日视图', GoalType.stage),
  week('周视图', GoalType.stage),
  month('月视图', GoalType.monthly),
  year('年视图', GoalType.yearly);

  const GoalViewMode(this.label, this.goalType);

  final String label;
  final GoalType goalType;
}

enum GoalSortOption {
  updatedDesc('最近更新'),
  progressDesc('进度优先'),
  titleAsc('标题 A-Z');

  const GoalSortOption(this.label);

  final String label;
}

class GoalPage extends ConsumerStatefulWidget {
  const GoalPage({super.key});

  @override
  ConsumerState<GoalPage> createState() => _GoalPageState();
}

class _GoalPageState extends ConsumerState<GoalPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  GoalType _selectedType = GoalType.stage;
  GoalStatus? _selectedStatus;
  GoalSortOption _sortOption = GoalSortOption.updatedDesc;
  GoalProgressMode _selectedProgressMode = GoalProgressMode.mixed;
  double _todoWeight = 0.7;
  double _todoUnitWeight = 1.0;
  double _habitUnitWeight = 0.5;
  TodoPriority _selectedPriority = TodoPriority.notUrgentImportant;
  bool _isCreating = false;

  GoalViewMode _selectedView = GoalViewMode.day;
  DateTime _focusDate = DateTime.now();
  // slot key → controller for per-row inline add
  final Map<String, TextEditingController> _slotControllers = {};
  String? _creatingSlot;

  TextEditingController _slotController(String key) {
    return _slotControllers.putIfAbsent(key, TextEditingController.new);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    for (final c in _slotControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(goalSummaryProvider);
    final goals = ref.watch(goalOverviewListProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('目标', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '设定中长期目标，拆解为待办和习惯，追踪进度。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _GoalSummaryCard(summary: summary),
          const SizedBox(height: 16),
          // View mode selector
          SegmentedButton<GoalViewMode>(
            segments: GoalViewMode.values
                .map(
                  (v) => ButtonSegment<GoalViewMode>(
                    value: v,
                    label: Text(v.label),
                  ),
                )
                .toList(),
            selected: {_selectedView},
            onSelectionChanged: (s) =>
                setState(() => _selectedView = s.first),
          ),
          const SizedBox(height: 10),
          // Date navigation
          _GoalViewDateHeader(
            viewMode: _selectedView,
            focusDate: _focusDate,
            onPrev: () => setState(() {
              _focusDate = _shiftDate(_focusDate, _selectedView, -1);
            }),
            onNext: () => setState(() {
              _focusDate = _shiftDate(_focusDate, _selectedView, 1);
            }),
            onToday: () => setState(() => _focusDate = DateTime.now()),
          ),
          const SizedBox(height: 8),
          // Goal view card
          goals.when(
            data: (items) {
              return _GoalTimelineCard(
                viewMode: _selectedView,
                focusDate: _focusDate,
                creatingSlot: _creatingSlot,
                controllerForSlot: _slotController,
                onSubmit: _createGoalFromSlot,
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _GoalErrorCard(message: '视图加载失败：$e'),
          ),
          const SizedBox(height: 16),
          _GoalCreateCard(
            titleController: _titleController,
            targetController: _targetController,
            unitController: _unitController,
            selectedType: _selectedType,
            selectedProgressMode: _selectedProgressMode,
            todoWeight: _todoWeight,
            todoUnitWeight: _todoUnitWeight,
            habitUnitWeight: _habitUnitWeight,
            selectedPriority: _selectedPriority,
            isCreating: _isCreating,
            onTypeChanged: (value) => setState(() => _selectedType = value),
            onProgressModeChanged: (value) =>
                setState(() => _selectedProgressMode = value),
            onTodoWeightChanged: (value) => setState(() => _todoWeight = value),
            onTodoUnitWeightChanged: (value) =>
                setState(() => _todoUnitWeight = value),
            onHabitUnitWeightChanged: (value) =>
                setState(() => _habitUnitWeight = value),
            onPriorityChanged: (value) =>
                setState(() => _selectedPriority = value),
            onSubmit: _createGoal,
          ),
          const SizedBox(height: 16),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索目标',
            hintText: '按标题或进度描述搜索',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('全部状态'),
                selected: _selectedStatus == null,
                onSelected: (_) => setState(() => _selectedStatus = null),
              ),
              ...GoalStatus.values.map(
                (status) => ChoiceChip(
                  label: Text(status.label),
                  selected: _selectedStatus == status,
                  onSelected: (_) => setState(() => _selectedStatus = status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectionChipBar<GoalSortOption>(
            values: GoalSortOption.values,
            selected: _sortOption,
            labelBuilder: (option) => option.label,
            onSelected: (option) => setState(() => _sortOption = option),
          ),
          const SizedBox(height: 16),
          goals.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyGoalState();
              }

              final normalizedSearch = _searchController.text
                  .trim()
                  .toLowerCase();
              final filtered = items.where((item) {
                final matchesStatus =
                    _selectedStatus == null ||
                    item.goal.status == _selectedStatus!.value;
                if (!matchesStatus) {
                  return false;
                }
                if (normalizedSearch.isEmpty) {
                  return true;
                }
                return item.goal.title.toLowerCase().contains(
                      normalizedSearch,
                    ) ||
                    item.progressDescription.toLowerCase().contains(
                      normalizedSearch,
                    );
              }).toList();

              if (filtered.isEmpty) {
                return const _GoalErrorCard(message: '当前筛选条件下没有目标。');
              }
              final sorted = filtered.toList()
                ..sort((left, right) {
                  switch (_sortOption) {
                    case GoalSortOption.updatedDesc:
                      return right.goal.updatedAt.compareTo(
                        left.goal.updatedAt,
                      );
                    case GoalSortOption.progressDesc:
                      final ratioDiff = right.progressRatio.compareTo(
                        left.progressRatio,
                      );
                      if (ratioDiff != 0) {
                        return ratioDiff;
                      }
                      return right.goal.updatedAt.compareTo(
                        left.goal.updatedAt,
                      );
                    case GoalSortOption.titleAsc:
                      return left.goal.title.compareTo(right.goal.title);
                  }
                });

              return Column(
                children: sorted
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalOverviewCard(
                          overview: item,
                          onEdit: () => _openEditGoalSheet(item.goal),
                          onCreateTodo: () => _openCreateTodoSheet(item.goal),
                          onCreateHabit: () => _openCreateHabitSheet(item.goal),
                          onViewDetail: () =>
                              context.push('/goal/${item.goal.id}'),
                          onViewTodos: () =>
                              context.push('/goal/${item.goal.id}/todos'),
                          onViewHabits: () =>
                              context.push('/goal/${item.goal.id}/habits'),
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
                _GoalErrorCard(message: '目标列表加载失败：$error'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGoal() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isCreating) {
      return;
    }

    setState(() => _isCreating = true);
    try {
      await ref
          .read(goalActionsProvider)
          .createGoal(
            title: title,
            goalType: _selectedType,
            progressMode: _selectedProgressMode,
            todoWeight: _todoWeight,
            habitWeight: (1 - _todoWeight).toDouble(),
            todoUnitWeight: _todoUnitWeight,
            habitUnitWeight: _habitUnitWeight,
            progressTarget: double.tryParse(_targetController.text.trim()),
            unit: _unitController.text.trim().isEmpty
                ? null
                : _unitController.text.trim(),
            priority: _selectedPriority,
          );
      if (mounted) {
        _titleController.clear();
        _targetController.clear();
        _unitController.clear();
        setState(() {
          _selectedType = GoalType.stage;
          _selectedProgressMode = GoalProgressMode.mixed;
          _todoWeight = 0.7;
          _todoUnitWeight = 1.0;
          _habitUnitWeight = 0.5;
          _selectedPriority = TodoPriority.notUrgentImportant;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增目标失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  DateTime _shiftDate(DateTime date, GoalViewMode mode, int delta) {
    switch (mode) {
      case GoalViewMode.day:
        return date.add(Duration(days: delta));
      case GoalViewMode.week:
        return date.add(Duration(days: delta * 7));
      case GoalViewMode.month:
        return DateTime(date.year, date.month + delta, 1);
      case GoalViewMode.year:
        return DateTime(date.year + delta, date.month, 1);
    }
  }

  Future<void> _createGoalFromSlot(String slotKey) async {
    final controller = _slotControllers[slotKey];
    if (controller == null) return;
    final title = controller.text.trim();
    if (title.isEmpty || _creatingSlot != null) return;

    setState(() => _creatingSlot = slotKey);
    try {
      await ref.read(goalActionsProvider).createGoal(
            title: title,
            goalType: _selectedView.goalType,
            progressMode: GoalProgressMode.mixed,
            todoWeight: 0.7,
            habitWeight: 0.3,
            todoUnitWeight: 1.0,
            habitUnitWeight: 0.5,
            progressTarget: null,
            unit: null,
          );
      if (mounted) {
        controller.clear();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增目标失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _creatingSlot = null);
      }
    }
  }

  Future<void> _openEditGoalSheet(GoalsTableData goal) async {
    final titleController = TextEditingController(text: goal.title);
    final targetController = TextEditingController(
      text: goal.progressTarget?.toString() ?? '',
    );
    final progressController = TextEditingController(
      text: goal.progressValue?.toString() ?? '',
    );
    final unitController = TextEditingController(text: goal.unit ?? '');
    var selectedType = GoalType.fromValue(goal.goalType);
    var selectedStatus = GoalStatus.fromValue(goal.status);
    var selectedProgressMode = GoalProgressMode.fromValue(goal.progressMode);
    var selectedPriority = TodoPriority.fromValue(goal.priority);
    var todoWeight = goal.todoWeight;
    var todoUnitWeight = goal.todoUnitWeight;
    var habitUnitWeight = goal.habitUnitWeight;

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
                        '编辑目标',
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
                      _EnumChoiceGroup<GoalType>(
                        title: '目标类型',
                        value: selectedType,
                        values: GoalType.values,
                        labelBuilder: (item) => item.label,
                        onChanged: (value) =>
                            setModalState(() => selectedType = value),
                      ),
                      _EnumChoiceGroup<GoalStatus>(
                        title: '状态',
                        value: selectedStatus,
                        values: GoalStatus.values,
                        labelBuilder: (item) => item.label,
                        onChanged: (value) =>
                            setModalState(() => selectedStatus = value),
                      ),
                      _EnumChoiceGroup<TodoPriority>(
                        title: '优先级（四象限）',
                        value: selectedPriority,
                        values: TodoPriority.values,
                        labelBuilder: (item) => item.label,
                        onChanged: (value) =>
                            setModalState(() => selectedPriority = value),
                      ),
                      _EnumChoiceGroup<GoalProgressMode>(
                        title: '进度规则',
                        value: selectedProgressMode,
                        values: GoalProgressMode.values,
                        labelBuilder: (item) => item.label,
                        onChanged: (value) =>
                            setModalState(() => selectedProgressMode = value),
                      ),
                      if (selectedProgressMode ==
                          GoalProgressMode.weightedMixed) ...<Widget>[
                        Text(
                          '组权重：待办 ${(todoWeight * 100).round()}% / 习惯 ${((1 - todoWeight) * 100).round()}%',
                        ),
                        Slider(
                          value: todoWeight,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          onChanged: (value) =>
                              setModalState(() => todoWeight = value),
                        ),
                        Text('待办单次完成权重 ${todoUnitWeight.toStringAsFixed(1)}'),
                        Slider(
                          value: todoUnitWeight,
                          min: 0.1,
                          max: 2,
                          divisions: 19,
                          onChanged: (value) =>
                              setModalState(() => todoUnitWeight = value),
                        ),
                        Text('习惯单次打卡权重 ${habitUnitWeight.toStringAsFixed(1)}'),
                        Slider(
                          value: habitUnitWeight,
                          min: 0.1,
                          max: 2,
                          divisions: 19,
                          onChanged: (value) =>
                              setModalState(() => habitUnitWeight = value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: progressController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: '手动进度',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: targetController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: '目标值',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: '单位',
                          border: OutlineInputBorder(),
                        ),
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

      if (confirmed != true || !mounted) {
        return;
      }

      await ref
          .read(goalActionsProvider)
          .updateGoal(
            goal: goal,
            title: titleController.text.trim(),
            goalType: selectedType,
            progressMode: selectedProgressMode,
            todoWeight: todoWeight,
            habitWeight: (1 - todoWeight).toDouble(),
            todoUnitWeight: todoUnitWeight,
            habitUnitWeight: habitUnitWeight,
            status: selectedStatus,
            priority: selectedPriority,
            progressValue: double.tryParse(progressController.text.trim()),
            progressTarget: double.tryParse(targetController.text.trim()),
            unit: unitController.text.trim().isEmpty
                ? null
                : unitController.text.trim(),
          );
    } finally {
      titleController.dispose();
      targetController.dispose();
      progressController.dispose();
      unitController.dispose();
    }
  }

  Future<void> _openCreateTodoSheet(GoalsTableData goal) async {
    final titleController = TextEditingController();
    var priority = TodoPriority.notUrgentImportant;
    var dueToday = true;

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
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
                        '为目标新增待办',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(goal.title),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '待办标题',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _EnumChoiceGroup<TodoPriority>(
                        title: '优先级',
                        value: priority,
                        values: TodoPriority.values,
                        labelBuilder: (item) => item.label,
                        onChanged: (value) =>
                            setModalState(() => priority = value),
                      ),
                      SwitchListTile(
                        value: dueToday,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('今天处理'),
                        onChanged: (value) =>
                            setModalState(() => dueToday = value),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('创建待办'),
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

      await ref
          .read(todoActionsProvider)
          .createTodo(
            title: titleController.text.trim(),
            priority: priority,
            dueToday: dueToday,
            goalId: goal.id,
          );
    } finally {
      titleController.dispose();
    }
  }

  Future<void> _openCreateHabitSheet(GoalsTableData goal) async {
    final nameController = TextEditingController();
    var reminderPreset = HabitReminderPreset.none;

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
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
                        '为目标新增习惯',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(goal.title),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '习惯名称',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _EnumChoiceGroup<HabitReminderPreset>(
                        title: '提醒预设',
                        value: reminderPreset,
                        values: const <HabitReminderPreset>[
                          HabitReminderPreset.none,
                          HabitReminderPreset.morning,
                          HabitReminderPreset.evening,
                        ],
                        labelBuilder: (item) => item.label,
                        onChanged: (value) =>
                            setModalState(() => reminderPreset = value),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('创建习惯'),
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

      await ref
          .read(habitActionsProvider)
          .createHabit(
            name: nameController.text.trim(),
            reminderTime: reminderPreset.value,
            goalId: goal.id,
          );
    } finally {
      nameController.dispose();
    }
  }
}

class _GoalViewDateHeader extends StatelessWidget {
  const _GoalViewDateHeader({
    required this.viewMode,
    required this.focusDate,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final GoalViewMode viewMode;
  final DateTime focusDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  String get _label {
    switch (viewMode) {
      case GoalViewMode.day:
        return DateFormat('M月d日 EEEE', 'zh').format(focusDate);
      case GoalViewMode.week:
        final start = focusDate.subtract(
          Duration(days: focusDate.weekday - 1),
        );
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('M月d日', 'zh').format(start)} — ${DateFormat('M月d日', 'zh').format(end)}';
      case GoalViewMode.month:
        return DateFormat('yyyy年M月', 'zh').format(focusDate);
      case GoalViewMode.year:
        return DateFormat('yyyy年', 'zh').format(focusDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isCurrentPeriod();
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onToday,
            child: Text(
              _label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    switch (viewMode) {
      case GoalViewMode.day:
        return focusDate.year == now.year &&
            focusDate.month == now.month &&
            focusDate.day == now.day;
      case GoalViewMode.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return !focusDate.isBefore(startOfWeek) &&
            !focusDate.isAfter(endOfWeek);
      case GoalViewMode.month:
        return focusDate.year == now.year && focusDate.month == now.month;
      case GoalViewMode.year:
        return focusDate.year == now.year;
    }
  }
}

class _GoalTimelineCard extends StatelessWidget {
  const _GoalTimelineCard({
    required this.viewMode,
    required this.focusDate,
    required this.creatingSlot,
    required this.controllerForSlot,
    required this.onSubmit,
  });

  final GoalViewMode viewMode;
  final DateTime focusDate;
  final String? creatingSlot;
  final TextEditingController Function(String key) controllerForSlot;
  final ValueChanged<String> onSubmit;

  List<_TimeSlot> get _slots {
    switch (viewMode) {
      case GoalViewMode.day:
        return List.generate(
          24,
          (h) => _TimeSlot(
            key: 'h$h',
            label: '${h.toString().padLeft(2, '0')}:00',
          ),
        );
      case GoalViewMode.week:
        final monday = focusDate.subtract(
          Duration(days: focusDate.weekday - 1),
        );
        const weekdays = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        return List.generate(
          7,
          (i) {
            final d = monday.add(Duration(days: i));
            return _TimeSlot(
              key: 'w$i',
              label: '${weekdays[i]}\n${d.month}/${d.day}',
            );
          },
        );
      case GoalViewMode.month:
        // weeks of the month
        final firstDay = DateTime(focusDate.year, focusDate.month, 1);
        final lastDay = DateTime(focusDate.year, focusDate.month + 1, 0);
        final slots = <_TimeSlot>[];
        var weekStart = firstDay;
        var weekNum = 1;
        while (weekStart.isBefore(lastDay) ||
            weekStart.isAtSameMomentAs(lastDay)) {
          final weekEnd = weekStart.add(const Duration(days: 6));
          final end = weekEnd.isAfter(lastDay) ? lastDay : weekEnd;
          slots.add(
            _TimeSlot(
              key: 'mw$weekNum',
              label: '第$weekNum周\n${weekStart.day}—${end.day}日',
            ),
          );
          weekStart = weekStart.add(const Duration(days: 7));
          weekNum++;
        }
        return slots;
      case GoalViewMode.year:
        const months = <String>[
          '1月', '2月', '3月', '4月', '5月', '6月',
          '7月', '8月', '9月', '10月', '11月', '12月',
        ];
        return List.generate(
          12,
          (i) => _TimeSlot(key: 'ym${i + 1}', label: months[i]),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final now = DateTime.now();
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: slots.map((slot) {
          final isCreating = creatingSlot == slot.key;
          final controller = controllerForSlot(slot.key);
          // highlight current slot
          final isCurrent = _isCurrentSlot(slot, now);

          return Container(
            decoration: isCurrent
                ? BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                  )
                : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Left: time label
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: theme.dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      slot.label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                        fontWeight: isCurrent ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  // Right: inline add only
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: isCreating
                          ? const SizedBox(
                              height: 32,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : TextField(
                              controller: controller,
                              enabled: creatingSlot == null,
                              decoration: const InputDecoration(
                                hintText: '添加目标…',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => onSubmit(slot.key),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isCurrentSlot(_TimeSlot slot, DateTime now) {
    switch (viewMode) {
      case GoalViewMode.day:
        return focusDate.year == now.year &&
            focusDate.month == now.month &&
            focusDate.day == now.day &&
            slot.key == 'h${now.hour}';
      case GoalViewMode.week:
        final monday = focusDate.subtract(
          Duration(days: focusDate.weekday - 1),
        );
        final weekContainsToday = monday.year == now.year ||
            monday.month == now.month ||
            monday.day <= now.day;
        if (!weekContainsToday) return false;
        final todayWeekday = now.weekday - 1; // 0-based
        return slot.key == 'w$todayWeekday';
      case GoalViewMode.month:
        if (focusDate.year != now.year || focusDate.month != now.month) {
          return false;
        }
        final firstDay = DateTime(now.year, now.month, 1);
        final dayOffset = now.day - firstDay.day;
        final weekNum = (dayOffset ~/ 7) + 1;
        return slot.key == 'mw$weekNum';
      case GoalViewMode.year:
        return focusDate.year == now.year && slot.key == 'ym${now.month}';
    }
  }
}

class _TimeSlot {
  const _TimeSlot({required this.key, required this.label});

  final String key;
  final String label;
}

class _GoalSummaryCard extends StatelessWidget {
  const _GoalSummaryCard({required this.summary});

  final AsyncValue<GoalSummary> summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: summary.when(
          data: (value) => Row(
            children: <Widget>[
              Expanded(
                child: _GoalMetric(label: '总数', value: '${value.total}'),
              ),
              Expanded(
                child: _GoalMetric(label: '进行中', value: '${value.active}'),
              ),
              Expanded(
                child: _GoalMetric(label: '已完成', value: '${value.completed}'),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('目标统计加载失败：$error'),
        ),
      ),
    );
  }
}

class _GoalMetric extends StatelessWidget {
  const _GoalMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    );
  }
}

class _GoalCreateCard extends StatelessWidget {
  const _GoalCreateCard({
    required this.titleController,
    required this.targetController,
    required this.unitController,
    required this.selectedType,
    required this.selectedProgressMode,
    required this.todoWeight,
    required this.todoUnitWeight,
    required this.habitUnitWeight,
    required this.selectedPriority,
    required this.isCreating,
    required this.onTypeChanged,
    required this.onProgressModeChanged,
    required this.onTodoWeightChanged,
    required this.onTodoUnitWeightChanged,
    required this.onHabitUnitWeightChanged,
    required this.onPriorityChanged,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TextEditingController targetController;
  final TextEditingController unitController;
  final GoalType selectedType;
  final GoalProgressMode selectedProgressMode;
  final double todoWeight;
  final double todoUnitWeight;
  final double habitUnitWeight;
  final TodoPriority selectedPriority;
  final bool isCreating;
  final ValueChanged<GoalType> onTypeChanged;
  final ValueChanged<GoalProgressMode> onProgressModeChanged;
  final ValueChanged<double> onTodoWeightChanged;
  final ValueChanged<double> onTodoUnitWeightChanged;
  final ValueChanged<double> onHabitUnitWeightChanged;
  final ValueChanged<TodoPriority> onPriorityChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('快速新增目标', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              enabled: !isCreating,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _EnumChoiceGroup<GoalType>(
              title: '目标类型',
              value: selectedType,
              values: GoalType.values,
              labelBuilder: (item) => item.label,
              onChanged: onTypeChanged,
            ),
            _EnumChoiceGroup<TodoPriority>(
              title: '优先级（四象限）',
              value: selectedPriority,
              values: TodoPriority.values,
              labelBuilder: (item) => item.label,
              onChanged: onPriorityChanged,
            ),
            _EnumChoiceGroup<GoalProgressMode>(
              title: '进度规则',
              value: selectedProgressMode,
              values: GoalProgressMode.values,
              labelBuilder: (item) => item.label,
              onChanged: onProgressModeChanged,
            ),
            if (selectedProgressMode ==
                GoalProgressMode.weightedMixed) ...<Widget>[
              Text(
                '组权重：待办 ${(todoWeight * 100).round()}% / 习惯 ${((1 - todoWeight) * 100).round()}%',
              ),
              Slider(
                value: todoWeight,
                min: 0,
                max: 1,
                divisions: 10,
                onChanged: isCreating ? null : onTodoWeightChanged,
              ),
              Text('待办单次完成权重 ${todoUnitWeight.toStringAsFixed(1)}'),
              Slider(
                value: todoUnitWeight,
                min: 0.1,
                max: 2,
                divisions: 19,
                onChanged: isCreating ? null : onTodoUnitWeightChanged,
              ),
              Text('习惯单次打卡权重 ${habitUnitWeight.toStringAsFixed(1)}'),
              Slider(
                value: habitUnitWeight,
                min: 0.1,
                max: 2,
                divisions: 19,
                onChanged: isCreating ? null : onHabitUnitWeightChanged,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: targetController,
                    enabled: !isCreating,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '目标值',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    enabled: !isCreating,
                    decoration: const InputDecoration(
                      labelText: '单位',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                label: Text(isCreating ? '保存中' : '新增目标'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnumChoiceGroup<T> extends StatelessWidget {
  const _EnumChoiceGroup({
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

class _GoalOverviewCard extends StatelessWidget {
  const _GoalOverviewCard({
    required this.overview,
    required this.onEdit,
    required this.onCreateTodo,
    required this.onCreateHabit,
    required this.onViewDetail,
    required this.onViewTodos,
    required this.onViewHabits,
  });

  final GoalOverview overview;
  final VoidCallback onEdit;
  final VoidCallback onCreateTodo;
  final VoidCallback onCreateHabit;
  final VoidCallback onViewDetail;
  final VoidCallback onViewTodos;
  final VoidCallback onViewHabits;

  @override
  Widget build(BuildContext context) {
    final goal = overview.goal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    goal.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _GoalTag(label: GoalType.fromValue(goal.goalType).label),
                _GoalTag(label: GoalStatus.fromValue(goal.status).label),
                _PriorityTag(priority: TodoPriority.fromValue(goal.priority)),
                _GoalTag(
                  label: GoalProgressMode.fromValue(goal.progressMode).label,
                ),
                _GoalTag(label: '待办 ${overview.linkedTodoCount}'),
                _GoalTag(label: '习惯 ${overview.linkedHabitCount}'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: overview.progressRatio),
            const SizedBox(height: 8),
            Text(overview.progressDescription),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: onCreateTodo,
                  icon: const Icon(Icons.checklist_outlined),
                  label: const Text('加待办'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateHabit,
                  icon: const Icon(Icons.bolt_outlined),
                  label: const Text('加习惯'),
                ),
                TextButton(onPressed: onViewDetail, child: const Text('详情')),
                TextButton(onPressed: onViewTodos, child: const Text('查看关联待办')),
                TextButton(
                  onPressed: onViewHabits,
                  child: const Text('查看关联习惯'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTag extends StatelessWidget {
  const _GoalTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label));
  }
}

class _PriorityTag extends StatelessWidget {
  const _PriorityTag({required this.priority});

  final TodoPriority priority;

  Color _color(BuildContext context) {
    switch (priority) {
      case TodoPriority.urgentImportant:
        return const Color(0xFFD32F2F);
      case TodoPriority.notUrgentImportant:
        return const Color(0xFF1565C0);
      case TodoPriority.urgentNotImportant:
        return const Color(0xFFE65100);
      case TodoPriority.notUrgentNotImportant:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Chip(
      label: Text(priority.label, style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _EmptyGoalState extends StatelessWidget {
  const _EmptyGoalState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.flag_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('还没有目标', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('先新增一个目标，再把待办和习惯关联进去。'),
          ],
        ),
      ),
    );
  }
}

class _GoalErrorCard extends StatelessWidget {
  const _GoalErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}
