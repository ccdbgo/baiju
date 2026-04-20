import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum GoalHabitFilter {
  all('全部'),
  checkedToday('今日已打卡'),
  pendingToday('今日未打卡');

  const GoalHabitFilter(this.label);

  final String label;
}

class GoalHabitsPage extends ConsumerStatefulWidget {
  const GoalHabitsPage({required this.goalId, super.key});

  final String goalId;

  @override
  ConsumerState<GoalHabitsPage> createState() => _GoalHabitsPageState();
}

class _GoalHabitsPageState extends ConsumerState<GoalHabitsPage> {
  GoalHabitFilter _filter = GoalHabitFilter.all;

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(goalHabitDetailsProvider(widget.goalId));

    return Scaffold(
      appBar: AppBar(title: const Text('关联习惯')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GoalHabitFilter.values.map((item) {
              return ChoiceChip(
                label: Text(item.label),
                selected: item == _filter,
                onSelected: (_) => setState(() => _filter = item),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          habits.when(
            data: (items) {
              final filtered = switch (_filter) {
                GoalHabitFilter.all => items,
                GoalHabitFilter.checkedToday =>
                  items.where((item) => item.checkedToday).toList(),
                GoalHabitFilter.pendingToday =>
                  items.where((item) => !item.checkedToday).toList(),
              };

              if (filtered.isEmpty) {
                return const _EmptyState(text: '这个目标下还没有关联习惯');
              }

              return Column(
                children: filtered
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openEditHabitSheet(item.habit),
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
                                          item.habit.name,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.push(
                                          '/habit/${item.habit.id}',
                                        ),
                                        child: const Text('详情'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(item.checkedToday ? '今天已打卡' : '今天未打卡'),
                                  if (item.habit.reminderTime !=
                                      null) ...<Widget>[
                                    const SizedBox(height: 8),
                                    Text('提醒 ${item.habit.reminderTime}'),
                                  ],
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

  Future<void> _openEditHabitSheet(HabitsTableData habit) async {
    final controller = TextEditingController(text: habit.name);
    var selectedReminder = HabitReminderPreset.fromReminderTime(
      habit.reminderTime,
    );
    TimeOfDay? customReminder = _parseReminderTime(habit.reminderTime);

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final customLabel = customReminder == null
                  ? '选择时间'
                  : '${customReminder!.hour.toString().padLeft(2, '0')}:${customReminder!.minute.toString().padLeft(2, '0')}';

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '编辑习惯',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: '名称',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: HabitReminderPreset.values.map((preset) {
                          return ChoiceChip(
                            label: Text(preset.label),
                            selected: preset == selectedReminder,
                            onSelected: (_) {
                              setModalState(() {
                                selectedReminder = preset;
                                if (preset != HabitReminderPreset.custom) {
                                  customReminder = null;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      if (selectedReminder ==
                          HabitReminderPreset.custom) ...<Widget>[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  customReminder ??
                                  const TimeOfDay(hour: 21, minute: 0),
                            );
                            if (picked != null) {
                              setModalState(() => customReminder = picked);
                            }
                          },
                          icon: const Icon(Icons.access_time_outlined),
                          label: Text(customLabel),
                        ),
                      ],
                      const SizedBox(height: 16),
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

      final reminderTime = switch (selectedReminder) {
        HabitReminderPreset.none => null,
        HabitReminderPreset.morning => HabitReminderPreset.morning.value,
        HabitReminderPreset.evening => HabitReminderPreset.evening.value,
        HabitReminderPreset.custom =>
          customReminder == null
              ? null
              : '${customReminder!.hour.toString().padLeft(2, '0')}:${customReminder!.minute.toString().padLeft(2, '0')}',
      };

      await ref
          .read(habitActionsProvider)
          .updateHabit(
            habit: habit,
            name: controller.text.trim(),
            reminderTime: reminderTime,
            goalId: habit.goalId,
          );
    } finally {
      controller.dispose();
    }
  }

  TimeOfDay? _parseReminderTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
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
