import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_editor_sheet.dart';
import 'package:baiju_app/features/note/presentation/widgets/related_notes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({required this.goalId, super.key});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalOverviewList = ref.watch(goalOverviewListProvider);
    final trend = ref.watch(goalTrendProvider(goalId));
    final relatedNotes = ref.watch(
      relatedNoteListProvider(
        NoteRelationTarget(entityType: 'goal', entityId: goalId),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('目标详情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          goalOverviewList.when(
            data: (items) {
              final matches = items.where((item) => item.goal.id == goalId);
              if (matches.isEmpty) {
                return const _EmptyState(text: '目标不存在或已删除');
              }
              final overview = matches.first;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          overview.goal.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _openEditGoalSheet(context, ref, overview.goal),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      Chip(
                        label: Text(
                          GoalStatus.fromValue(overview.goal.status).label,
                        ),
                      ),
                      Chip(label: Text(overview.progressMode.label)),
                      Chip(label: Text('待办 ${overview.linkedTodoCount}')),
                      Chip(label: Text('习惯 ${overview.linkedHabitCount}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: overview.progressRatio),
                  const SizedBox(height: 8),
                  Text(overview.progressDescription),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: () => context.push('/goal/$goalId/todos'),
                        child: const Text('查看关联待办'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.push('/goal/$goalId/habits'),
                        child: const Text('查看关联习惯'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  RelatedNotesSection(
                    relatedNotes: relatedNotes,
                    onCreate: () =>
                        _createRelatedNote(context, ref, overview.goal),
                    onOpenNote: (note) => context.push('/note/${note.id}'),
                  ),
                  const SizedBox(height: 20),
                  Text('状态操作', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      if (overview.goal.status == 'active' ||
                          overview.goal.status == 'paused')
                        OutlinedButton.icon(
                          onPressed: () =>
                              _togglePauseGoal(context, ref, overview.goal),
                          icon: Icon(
                            overview.goal.status == 'paused'
                                ? Icons.play_arrow_outlined
                                : Icons.pause_outlined,
                          ),
                          label: Text(
                            overview.goal.status == 'paused' ? '恢复' : '暂停',
                          ),
                        ),
                      if (overview.goal.status != GoalStatus.abandoned.value)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _archiveGoal(context, ref, overview.goal),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('归档'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _deleteGoal(context, ref, overview.goal),
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
            error: (error, stackTrace) => Text('目标加载失败：$error'),
          ),
          const SizedBox(height: 20),
          Text('近 7 天趋势', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          trend.when(
            data: (points) => _GoalTrendChart(points: points),
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => Text('趋势加载失败：$error'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditGoalSheet(
    BuildContext context,
    WidgetRef ref,
    GoalsTableData goal,
  ) async {
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                          '组合权重：待办 ${(todoWeight * 100).round()}% / 习惯 ${((1 - todoWeight) * 100).round()}%',
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

      if (confirmed != true) {
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

  Future<void> _togglePauseGoal(
    BuildContext context,
    WidgetRef ref,
    GoalsTableData goal,
  ) async {
    final paused = goal.status != 'paused';
    final confirmed = await _confirmAction(
      context,
      title: paused ? '暂停这个目标？' : '恢复这个目标？',
      message: paused ? '暂停后会保留关联关系，但不再视为进行中目标。' : '恢复后会重新回到进行中状态。',
      confirmLabel: paused ? '暂停' : '恢复',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(goalActionsProvider).setGoalPaused(goal, paused);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(paused ? '目标已暂停' : '目标已恢复')));
  }

  Future<void> _createRelatedNote(
    BuildContext context,
    WidgetRef ref,
    GoalsTableData goal,
  ) async {
    final result = await showNoteEditorSheet(
      context,
      title: '新增关联笔记',
      confirmLabel: '保存笔记',
      initialTitle: goal.title,
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
          relatedEntityType: 'goal',
          relatedEntityId: goal.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关联笔记已创建')));
    }
  }

  Future<void> _archiveGoal(
    BuildContext context,
    WidgetRef ref,
    GoalsTableData goal,
  ) async {
    final confirmed = await _confirmAction(
      context,
      title: '归档这个目标？',
      message: '归档后它会保留历史数据，但不再继续推进。',
      confirmLabel: '归档',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(goalActionsProvider).archiveGoal(goal);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('目标已归档')));
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    GoalsTableData goal,
  ) async {
    final confirmed = await _confirmAction(
      context,
      title: '删除这个目标？',
      message: '删除后目标会从目标列表中移除，但时间线记录会保留。',
      confirmLabel: '删除',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(goalActionsProvider).deleteGoal(goal);
    if (!context.mounted) {
      return;
    }
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('目标已删除')));
  }

  Future<bool?> _confirmAction(
    BuildContext context, {
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

class _GoalTrendChart extends StatelessWidget {
  const _GoalTrendChart({required this.points});

  final List<GoalTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyState(text: '近 7 天暂无趋势数据');
    }

    final maxValue = points
        .expand((point) => <int>[point.completedTodos, point.checkedHabits])
        .fold<int>(0, (max, value) => value > max ? value : max);
    final axisMax = _normalizeAxisMax(maxValue);
    final ticks = <int>[axisMax, (axisMax / 2).ceil(), 0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: const <Widget>[
            _TrendLegend(color: Color(0xFF136F63), label: '待办完成'),
            _TrendLegend(color: Color(0xFFC06C00), label: '习惯打卡'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '纵轴：次数，横轴：近 7 天按日统计',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 28,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: ticks
                      .map(
                        (tick) => Text(
                          '$tick',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const labelHeight = 24.0;
                    final chartHeight = constraints.maxHeight - labelHeight;
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          bottom: labelHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List<Widget>.generate(
                              ticks.length,
                              (index) => Container(
                                height: 1,
                                color: const Color(0xFFE3DED2),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: points
                                .map(
                                  (point) => Expanded(
                                    child: _GoalTrendGroup(
                                      point: point,
                                      axisMax: axisMax,
                                      chartHeight: chartHeight,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _normalizeAxisMax(int value) {
    if (value <= 4) {
      return 4;
    }
    final step = value <= 10 ? 2 : 5;
    return ((value + step - 1) ~/ step) * step;
  }
}

class _GoalTrendGroup extends StatelessWidget {
  const _GoalTrendGroup({
    required this.point,
    required this.axisMax,
    required this.chartHeight,
  });

  final GoalTrendPoint point;
  final int axisMax;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final todoRatio = point.completedTodos / axisMax;
    final habitRatio = point.checkedHabits / axisMax;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          SizedBox(
            height: chartHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _TrendBar(
                    value: point.completedTodos,
                    height: chartHeight * todoRatio,
                    color: const Color(0xFF136F63),
                  ),
                  const SizedBox(width: 6),
                  _TrendBar(
                    value: point.checkedHabits,
                    height: chartHeight * habitRatio,
                    color: const Color(0xFFC06C00),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('M/d').format(point.date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.value,
    required this.height,
    required this.color,
  });

  final int value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasValue = value > 0;
    return SizedBox(
      width: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          if (hasValue) ...<Widget>[
            Text('$value', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
          ],
          Container(
            width: 18,
            height: hasValue ? height.clamp(6, double.infinity) : 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
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
