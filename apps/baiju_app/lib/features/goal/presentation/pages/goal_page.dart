import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/schedule/presentation/widgets/schedule_calendar_views.dart';
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

  GoalStatus? _selectedStatus;
  GoalSortOption _sortOption = GoalSortOption.updatedDesc;

  GoalViewMode _selectedView = GoalViewMode.day;
  DateTime _focusDate = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
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
          // Date navigation header
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
          // Goal view card — shows goals in the selected time period
          goals.when(
            data: (items) => GoalViewCard(
              selectedView: _selectedView,
              focusDate: _focusDate,
              goals: items,
              onOpenDetail: (goal) => context.push('/goal/${goal.id}'),
              onCreateGoal: _createGoalFromSlot,
              onReschedule: _rescheduleGoal,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _GoalErrorCard(message: '视图加载失败：$e'),
          ),
          const SizedBox(height: 16),
          Text('目标列表', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
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

  Future<void> _createGoalFromSlot(String title, GoalType goalType, DateTime slotDate) async {
    if (title.isEmpty) return;
    try {
      await ref.read(goalActionsProvider).createGoal(
            title: title,
            goalType: goalType,
            progressMode: GoalProgressMode.mixed,
            todoWeight: 0.7,
            habitWeight: 0.3,
            todoUnitWeight: 1.0,
            habitUnitWeight: 0.5,
            progressTarget: null,
            unit: null,
            startDate: slotDate,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增目标失败：$error')),
        );
      }
    }
  }

  Future<void> _rescheduleGoal(GoalsTableData goal, DateTime newStartDate) async {
    try {
      await ref.read(goalActionsProvider).rescheduleGoal(goal, newStartDate);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('调整目标时间失败：$error')),
        );
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

// ─── Date header (styled like ViewHeader from schedule_calendar_views) ────────

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
        return DateFormat('M月d日').format(focusDate);
      case GoalViewMode.week:
        final start = startOfWeek(focusDate);
        return '${DateFormat('M月d日').format(start)} - ${DateFormat('M月d日').format(start.add(const Duration(days: 6)))}';
      case GoalViewMode.month:
        return DateFormat('yyyy年M月').format(focusDate);
      case GoalViewMode.year:
        return DateFormat('yyyy年').format(focusDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Text(
            _label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        TextButton(onPressed: onToday, child: const Text('今天')),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

// ─── GoalViewCard: routes to per-mode goal views (with inline add) ────────────

DateTime _goalEffectiveDate(GoalsTableData goal) =>
    (goal.startDate ?? goal.createdAt).toLocal();

/// [onCreateGoal] receives (title, goalType) when the user submits inline.
class GoalViewCard extends StatefulWidget {
  const GoalViewCard({
    required this.selectedView,
    required this.focusDate,
    required this.goals,
    required this.onOpenDetail,
    required this.onCreateGoal,
    required this.onReschedule,
    super.key,
  });

  final GoalViewMode selectedView;
  final DateTime focusDate;
  final List<GoalOverview> goals;
  final ValueChanged<GoalsTableData> onOpenDetail;
  final Future<void> Function(String title, GoalType goalType, DateTime slotDate) onCreateGoal;
  final Future<void> Function(GoalsTableData goal, DateTime newStartDate) onReschedule;

  @override
  State<GoalViewCard> createState() => _GoalViewCardState();
}

class _GoalViewCardState extends State<GoalViewCard> {
  // Active slot key (only one slot open at a time)
  String? _activeSlot;
  final TextEditingController _inputController = TextEditingController();
  bool _submitting = false;

  @override
  void didUpdateWidget(GoalViewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If view or date changed, close any open slot
    if (oldWidget.selectedView != widget.selectedView ||
        oldWidget.focusDate != widget.focusDate) {
      _activeSlot = null;
      _inputController.clear();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _activateSlot(String key) {
    setState(() {
      _activeSlot = key;
      _inputController.clear();
    });
  }

  Future<void> _submit(GoalType goalType, DateTime slotDate) async {
    final title = _inputController.text.trim();
    if (title.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onCreateGoal(title, goalType, slotDate);
      if (mounted) {
        _inputController.clear();
        setState(() => _activeSlot = null);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _cancelSlot() {
    setState(() {
      _activeSlot = null;
      _inputController.clear();
    });
  }

  /// Inline add row shown at the bottom of each slot's content column.
  Widget _buildInlineAdd(BuildContext context, String slotKey, GoalType goalType, DateTime slotDate) {
    final isActive = _activeSlot == slotKey;
    final theme = Theme.of(context);

    if (!isActive) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _activateSlot(slotKey),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '+ 点击添加目标',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _inputController,
              autofocus: true,
              enabled: !_submitting,
              decoration: InputDecoration(
                hintText: '输入目标名称，回车确认',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: const OutlineInputBorder(),
                suffixIcon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onSubmitted: (_) => _submit(goalType, slotDate),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _submitting ? null : () => _submit(goalType, slotDate),
            icon: const Icon(Icons.check, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: '确认',
          ),
          IconButton(
            onPressed: _cancelSlot,
            icon: const Icon(Icons.close, size: 18),
            visualDensity: VisualDensity.compact,
            tooltip: '取消',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalList = widget.goals.map((o) => o.goal).toList();
    final Widget content;
    switch (widget.selectedView) {
      case GoalViewMode.day:
        content = _DayGoalView(
          focusDate: widget.focusDate,
          goals: goalList,
          onOpenDetail: widget.onOpenDetail,
          buildInlineAdd: _buildInlineAdd,
          onReschedule: widget.onReschedule,
        );
      case GoalViewMode.week:
        content = _WeekGoalView(
          focusDate: widget.focusDate,
          goals: goalList,
          onOpenDetail: widget.onOpenDetail,
          buildInlineAdd: _buildInlineAdd,
          onReschedule: widget.onReschedule,
        );
      case GoalViewMode.month:
        content = _MonthGoalView(
          focusDate: widget.focusDate,
          goals: goalList,
          onOpenDetail: widget.onOpenDetail,
          buildInlineAdd: _buildInlineAdd,
          onReschedule: widget.onReschedule,
        );
      case GoalViewMode.year:
        content = _YearGoalView(
          focusDate: widget.focusDate,
          goals: goalList,
          onOpenDetail: widget.onOpenDetail,
          buildInlineAdd: _buildInlineAdd,
          onReschedule: widget.onReschedule,
        );
    }
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: content),
    );
  }
}

// ─── Day view ─────────────────────────────────────────────────────────────────

class _DayGoalView extends StatelessWidget {
  const _DayGoalView({
    required this.focusDate,
    required this.goals,
    required this.onOpenDetail,
    required this.buildInlineAdd,
    required this.onReschedule,
  });

  final DateTime focusDate;
  final List<GoalsTableData> goals;
  final ValueChanged<GoalsTableData> onOpenDetail;
  final Widget Function(BuildContext, String slotKey, GoalType, DateTime slotDate) buildInlineAdd;
  final Future<void> Function(GoalsTableData goal, DateTime newStartDate) onReschedule;

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<GoalsTableData>>{};
    for (final g in goals.where((g) => sameDate(_goalEffectiveDate(g), focusDate))) {
      grouped
          .putIfAbsent(_goalEffectiveDate(g).hour, () => <GoalsTableData>[])
          .add(g);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(24, (hour) {
        final items = grouped[hour] ?? const <GoalsTableData>[];
        final slotDate = DateTime(focusDate.year, focusDate.month, focusDate.day, hour);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x11000000))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 52,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ...items.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: GoalSlotBlock(
                          goal: g,
                          onTap: () => onOpenDetail(g),
                          onReschedule: (newDate) => onReschedule(g, newDate),
                          rescheduleMode: _RescheduleMode.hour,
                          focusDate: focusDate,
                        ),
                      ),
                    ),
                    buildInlineAdd(context, 'day_h$hour', GoalType.stage, slotDate),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Week view ────────────────────────────────────────────────────────────────

class _WeekGoalView extends StatelessWidget {
  const _WeekGoalView({
    required this.focusDate,
    required this.goals,
    required this.onOpenDetail,
    required this.buildInlineAdd,
    required this.onReschedule,
  });

  final DateTime focusDate;
  final List<GoalsTableData> goals;
  final ValueChanged<GoalsTableData> onOpenDetail;
  final Widget Function(BuildContext, String slotKey, GoalType, DateTime slotDate) buildInlineAdd;
  final Future<void> Function(GoalsTableData goal, DateTime newStartDate) onReschedule;

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(focusDate);

    return Column(
      children: List<Widget>.generate(7, (index) {
        final day = weekStart.add(Duration(days: index));
        final dayGoals = goals
            .where((g) => sameDate(_goalEffectiveDate(g), day))
            .toList()
          ..sort((a, b) => _goalEffectiveDate(a).compareTo(_goalEffectiveDate(b)));
        final slotKey = 'week_d$index';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        weekdayShort(day.weekday),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        DateFormat('M月d日').format(day),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ...dayGoals.map(
                        (g) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GoalSlotBlock(
                            goal: g,
                            onTap: () => onOpenDetail(g),
                            onReschedule: (newDate) => onReschedule(g, newDate),
                            rescheduleMode: _RescheduleMode.day,
                            focusDate: focusDate,
                          ),
                        ),
                      ),
                      buildInlineAdd(context, slotKey, GoalType.stage, day),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Month view ───────────────────────────────────────────────────────────────

class _MonthGoalView extends StatelessWidget {
  const _MonthGoalView({
    required this.focusDate,
    required this.goals,
    required this.onOpenDetail,
    required this.buildInlineAdd,
    required this.onReschedule,
  });

  final DateTime focusDate;
  final List<GoalsTableData> goals;
  final ValueChanged<GoalsTableData> onOpenDetail;
  final Widget Function(BuildContext, String slotKey, GoalType, DateTime slotDate) buildInlineAdd;
  final Future<void> Function(GoalsTableData goal, DateTime newStartDate) onReschedule;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(focusDate.year, focusDate.month, 1);
    final gridStart = monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final theme = Theme.of(context);

    return Column(
      children: List<Widget>.generate(6, (weekIndex) {
        final weekStart = gridStart.add(Duration(days: weekIndex * 7));
        final weekEnd = weekStart.add(const Duration(days: 7));

        final hasCurrentMonth =
            List.generate(7, (i) => weekStart.add(Duration(days: i)))
                .any((d) => d.month == focusDate.month);
        if (!hasCurrentMonth) return const SizedBox.shrink();

        final weekGoals = goals.where((g) {
          final d = _goalEffectiveDate(g);
          return !d.isBefore(weekStart) && d.isBefore(weekEnd);
        }).toList()
          ..sort((a, b) => _goalEffectiveDate(a).compareTo(_goalEffectiveDate(b)));

        final weekLabel =
            '${DateFormat('M/d').format(weekStart)}–${DateFormat('M/d').format(weekEnd.subtract(const Duration(days: 1)))}';
        final slotKey = 'month_w$weekIndex';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '第${weekIndex + 1}周',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        weekLabel,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ...weekGoals.take(3).map(
                        (g) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GoalSlotBlock(
                            goal: g,
                            onTap: () => onOpenDetail(g),
                            onReschedule: (newDate) => onReschedule(g, newDate),
                            rescheduleMode: _RescheduleMode.week,
                            focusDate: focusDate,
                          ),
                        ),
                      ),
                      if (weekGoals.length > 3)
                        Text(
                          '还有 ${weekGoals.length - 3} 个...',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      buildInlineAdd(context, slotKey, GoalType.monthly, weekStart),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Year view ────────────────────────────────────────────────────────────────

class _YearGoalView extends StatelessWidget {
  const _YearGoalView({
    required this.focusDate,
    required this.goals,
    required this.onOpenDetail,
    required this.buildInlineAdd,
    required this.onReschedule,
  });

  final DateTime focusDate;
  final List<GoalsTableData> goals;
  final ValueChanged<GoalsTableData> onOpenDetail;
  final Widget Function(BuildContext, String slotKey, GoalType, DateTime slotDate) buildInlineAdd;
  final Future<void> Function(GoalsTableData goal, DateTime newStartDate) onReschedule;

  @override
  Widget build(BuildContext context) {
    final yearGoals = goals
        .where((g) => _goalEffectiveDate(g).year == focusDate.year)
        .toList();
    final theme = Theme.of(context);

    return Column(
      children: List<Widget>.generate(12, (index) {
        final month = index + 1;
        final monthGoals = yearGoals
            .where((g) => _goalEffectiveDate(g).month == month)
            .toList()
          ..sort((a, b) => _goalEffectiveDate(a).compareTo(_goalEffectiveDate(b)));
        final slotKey = 'year_m$month';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 48,
                  child: Text(
                    '$month月',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ...monthGoals.take(3).map(
                        (g) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: GoalSlotBlock(
                            goal: g,
                            onTap: () => onOpenDetail(g),
                            onReschedule: (newDate) => onReschedule(g, newDate),
                            rescheduleMode: _RescheduleMode.month,
                            focusDate: focusDate,
                          ),
                        ),
                      ),
                      if (monthGoals.length > 3)
                        Text(
                          '还有 ${monthGoals.length - 3} 个...',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      buildInlineAdd(context, slotKey, GoalType.yearly, DateTime(focusDate.year, month, 1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── Reschedule mode enum ─────────────────────────────────────────────────────

enum _RescheduleMode { hour, day, week, month }

// ─── GoalSlotBlock: single goal item in the day-view timeline ─────────────────

class GoalSlotBlock extends StatelessWidget {
  const GoalSlotBlock({
    required this.goal,
    required this.onTap,
    required this.onReschedule,
    required this.rescheduleMode,
    required this.focusDate,
    super.key,
  });

  final GoalsTableData goal;
  final VoidCallback onTap;
  final void Function(DateTime newDate) onReschedule;
  final _RescheduleMode rescheduleMode;
  final DateTime focusDate;

  Future<void> _showRescheduleDialog(BuildContext context) async {
    switch (rescheduleMode) {
      case _RescheduleMode.hour:
        await _pickHour(context);
      case _RescheduleMode.day:
        await _pickDay(context);
      case _RescheduleMode.week:
        await _pickWeek(context);
      case _RescheduleMode.month:
        await _pickMonth(context);
    }
  }

  Future<void> _pickHour(BuildContext context) async {
    final current = _goalEffectiveDate(goal);
    final hours = List<int>.generate(24, (i) => i);
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('调整到时段'),
        children: hours.map((h) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, h),
          child: Text('${h.toString().padLeft(2, '0')}:00',
            style: TextStyle(
              fontWeight: current.hour == h ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        )).toList(),
      ),
    );
    if (picked != null) {
      final newDate = DateTime(current.year, current.month, current.day, picked);
      onReschedule(newDate);
    }
  }

  Future<void> _pickDay(BuildContext context) async {
    final weekStart = startOfWeek(focusDate);
    final days = List<DateTime>.generate(7, (i) => weekStart.add(Duration(days: i)));
    final current = _goalEffectiveDate(goal);
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('调整到星期'),
        children: days.map((d) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, d),
          child: Text('${weekdayShort(d.weekday)} ${DateFormat('M月d日').format(d)}',
            style: TextStyle(
              fontWeight: sameDate(d, current) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        )).toList(),
      ),
    );
    if (picked != null) {
      final newDate = DateTime(picked.year, picked.month, picked.day, current.hour);
      onReschedule(newDate);
    }
  }

  Future<void> _pickWeek(BuildContext context) async {
    final monthStart = DateTime(focusDate.year, focusDate.month, 1);
    final gridStart = monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final current = _goalEffectiveDate(goal);
    final weeks = <DateTime>[];
    for (var i = 0; i < 6; i++) {
      final ws = gridStart.add(Duration(days: i * 7));
      final hasMonth = List.generate(7, (j) => ws.add(Duration(days: j)))
          .any((d) => d.month == focusDate.month);
      if (hasMonth) weeks.add(ws);
    }
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('调整到周'),
        children: weeks.asMap().entries.map((e) {
          final ws = e.value;
          final we = ws.add(const Duration(days: 6));
          final label = '${DateFormat('M/d').format(ws)}–${DateFormat('M/d').format(we)}';
          final isCurrent = !current.isBefore(ws) && current.isBefore(ws.add(const Duration(days: 7)));
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ws),
            child: Text(label,
              style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
            ),
          );
        }).toList(),
      ),
    );
    if (picked != null) {
      onReschedule(picked);
    }
  }

  Future<void> _pickMonth(BuildContext context) async {
    final current = _goalEffectiveDate(goal);
    final months = List<int>.generate(12, (i) => i + 1);
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('调整到月份'),
        children: months.map((m) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, m),
          child: Text('$m月',
            style: TextStyle(
              fontWeight: current.month == m ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        )).toList(),
      ),
    );
    if (picked != null) {
      final newDate = DateTime(focusDate.year, picked, 1);
      onReschedule(newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8F2EF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: () => _showRescheduleDialog(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      goal.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      GoalStatus.fromValue(goal.status).label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.flag_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

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

// ─── Empty / error states ─────────────────────────────────────────────────────
