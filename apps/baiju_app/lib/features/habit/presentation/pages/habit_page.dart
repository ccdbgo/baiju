import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum HabitSortOption {
  goalLinkedFirst('目标优先'),
  reminderFirst('提醒优先'),
  nameAsc('名称 A-Z');

  const HabitSortOption(this.label);

  final String label;
}

class HabitPage extends ConsumerStatefulWidget {
  const HabitPage({super.key});

  @override
  ConsumerState<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends ConsumerState<HabitPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _pendingHabitIds = <String>{};

  HabitReminderPreset _selectedReminder = HabitReminderPreset.none;
  TimeOfDay? _customReminder;
  bool _showOnlyGoalLinked = false;
  HabitSortOption _sortOption = HabitSortOption.goalLinkedFirst;
  String? _selectedGoalId;
  double _progressWeight = 1.0;
  bool _isCreating = false;
  bool _isManagingReminders = false;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(habitSummaryProvider);
    final habits = ref.watch(habitListProvider);
    final goalOptions = ref.watch(goalOptionsProvider);
    final pendingReminderCount = ref.watch(pendingReminderCountProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('习惯', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '坚持每天打卡，养成好习惯。支持提醒、连续天数统计和目标关联。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _HabitSummaryCard(
            summary: summary,
            onTapAll: () => setState(() {
              _showOnlyGoalLinked = false;
              _selectedGoalId = null;
              _selectedReminder = HabitReminderPreset.none;
            }),
            onTapActive: () => setState(() {
              _showOnlyGoalLinked = false;
              _selectedGoalId = null;
              _selectedReminder = HabitReminderPreset.none;
            }),
            onTapCheckedToday: () => setState(() {
              _showOnlyGoalLinked = false;
              _selectedGoalId = null;
              _selectedReminder = HabitReminderPreset.none;
            }),
          ),
          const SizedBox(height: 16),
          _ReminderManagementCard(
            pendingReminderCount: pendingReminderCount,
            isBusy: _isManagingReminders,
            onSyncAll: _syncAllReminders,
            onClearAll: _clearAllReminders,
          ),
          const SizedBox(height: 16),
          _HabitCreateCard(
            controller: _nameController,
            isCreating: _isCreating,
            selectedReminder: _selectedReminder,
            customReminderLabel: _customReminderLabel,
            selectedGoalId: _selectedGoalId,
            progressWeight: _progressWeight,
            goalOptions: goalOptions,
            onReminderChanged: (value) {
              setState(() {
                _selectedReminder = value;
                if (value != HabitReminderPreset.custom) {
                  _customReminder = null;
                }
              });
            },
            onGoalChanged: (goalId) => setState(() => _selectedGoalId = goalId),
            onProgressWeightChanged: (value) =>
                setState(() => _progressWeight = value),
            onPickCustomTime: _pickCustomTime,
            onSubmit: _createHabit,
          ),
          const SizedBox(height: 16),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索习惯',
            hintText: '按名称搜索',
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            value: _showOnlyGoalLinked,
            contentPadding: EdgeInsets.zero,
            title: const Text('仅看已关联目标的习惯'),
            onChanged: (value) => setState(() => _showOnlyGoalLinked = value),
          ),
          SelectionChipBar<HabitSortOption>(
            values: HabitSortOption.values,
            selected: _sortOption,
            labelBuilder: (option) => option.label,
            onSelected: (option) => setState(() => _sortOption = option),
          ),
          habits.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyHabitState();
              }

              final normalizedSearch = _searchController.text
                  .trim()
                  .toLowerCase();
              final filtered = items.where((item) {
                final matchesGoal =
                    !_showOnlyGoalLinked || item.habit.goalId != null;
                if (!matchesGoal) {
                  return false;
                }
                if (normalizedSearch.isEmpty) {
                  return true;
                }
                return item.habit.name.toLowerCase().contains(normalizedSearch);
              }).toList();

              if (filtered.isEmpty) {
                return const _HabitErrorCard(message: '当前筛选条件下没有习惯。');
              }
              final sorted = filtered.toList()
                ..sort((left, right) {
                  switch (_sortOption) {
                    case HabitSortOption.goalLinkedFirst:
                      final leftLinked = left.habit.goalId != null ? 1 : 0;
                      final rightLinked = right.habit.goalId != null ? 1 : 0;
                      final diff = rightLinked.compareTo(leftLinked);
                      if (diff != 0) {
                        return diff;
                      }
                      return left.habit.name.compareTo(right.habit.name);
                    case HabitSortOption.reminderFirst:
                      final leftReminder = left.habit.reminderTime ?? '99:99';
                      final rightReminder = right.habit.reminderTime ?? '99:99';
                      final diff = leftReminder.compareTo(rightReminder);
                      if (diff != 0) {
                        return diff;
                      }
                      return left.habit.name.compareTo(right.habit.name);
                    case HabitSortOption.nameAsc:
                      return left.habit.name.compareTo(right.habit.name);
                  }
                });

              return Column(
                children: sorted
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HabitListItem(
                          item: item,
                          isPending: _pendingHabitIds.contains(item.habit.id),
                          onChanged: (value) =>
                              _toggleCheckIn(item, value ?? false),
                          onOpenDetail: () =>
                              context.push('/habit/${item.habit.id}'),
                          onEdit: () => _openEditHabitSheet(item.habit),
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
                _HabitErrorCard(message: '习惯列表加载失败：$error'),
          ),
        ],
      ),
    );
  }

  String get _customReminderLabel {
    if (_customReminder == null) {
      return '选择时间';
    }
    final hour = _customReminder!.hour.toString().padLeft(2, '0');
    final minute = _customReminder!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? get _selectedReminderTime {
    switch (_selectedReminder) {
      case HabitReminderPreset.none:
        return null;
      case HabitReminderPreset.morning:
      case HabitReminderPreset.evening:
        return _selectedReminder.value;
      case HabitReminderPreset.custom:
        if (_customReminder == null) {
          return null;
        }
        final hour = _customReminder!.hour.toString().padLeft(2, '0');
        final minute = _customReminder!.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
    }
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _customReminder ?? const TimeOfDay(hour: 21, minute: 0),
    );

    if (picked != null) {
      setState(() {
        _selectedReminder = HabitReminderPreset.custom;
        _customReminder = picked;
      });
    }
  }

  Future<void> _createHabit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _isCreating) {
      return;
    }
    if (_selectedReminder == HabitReminderPreset.custom &&
        _customReminder == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('先选择自定义提醒时间')));
      return;
    }

    setState(() => _isCreating = true);
    try {
      await ref
          .read(habitActionsProvider)
          .createHabit(
            name: name,
            reminderTime: _selectedReminderTime,
            goalId: _selectedGoalId,
            progressWeight: _progressWeight,
          );
      ref.invalidate(pendingReminderCountProvider);
      _nameController.clear();
      if (mounted) {
        setState(() {
          _selectedReminder = HabitReminderPreset.none;
          _customReminder = null;
          _selectedGoalId = null;
          _progressWeight = 1.0;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增习惯失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _toggleCheckIn(HabitTodayItem item, bool checked) async {
    if (_pendingHabitIds.contains(item.habit.id)) {
      return;
    }

    setState(() => _pendingHabitIds.add(item.habit.id));
    try {
      await ref.read(habitActionsProvider).toggleHabitCheckIn(item, checked);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新习惯状态失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingHabitIds.remove(item.habit.id));
      }
    }
  }

  Future<void> _openEditHabitSheet(HabitsTableData habit) async {
    final controller = TextEditingController(text: habit.name);
    var selectedReminder = HabitReminderPreset.fromReminderTime(
      habit.reminderTime,
    );
    TimeOfDay? customReminder = _parseReminderTime(habit.reminderTime);
    String? selectedGoalId = habit.goalId;
    double progressWeight = habit.progressWeight;
    final goalOptions = await ref.read(goalOptionsProvider.future);

    try {
      if (!mounted) {
        return;
      }
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final customLabel = customReminder == null
                  ? '选择时间'
                  : '${customReminder!.hour.toString().padLeft(2, '0')}:${customReminder!.minute.toString().padLeft(2, '0')}';

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
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
                      DropdownButtonFormField<String?>(
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
                          ...goalOptions.map(
                            (goal) => DropdownMenuItem<String?>(
                              value: goal.id,
                              child: Text(goal.title),
                            ),
                          ),
                        ],
                        onChanged: (value) => setModalState(() {
                          selectedGoalId = value;
                          if (value == null) {
                            progressWeight = 1.0;
                          }
                        }),
                      ),
                      if (selectedGoalId != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text('目标进度权重 ${progressWeight.toStringAsFixed(1)}'),
                        Slider(
                          value: progressWeight,
                          min: 0.1,
                          max: 2,
                          divisions: 19,
                          onChanged: (value) =>
                              setModalState(() => progressWeight = value),
                        ),
                      ],
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
            goalId: selectedGoalId,
            progressWeight: progressWeight,
          );
      ref.invalidate(pendingReminderCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('习惯已更新')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新习惯失败：$error')));
      }
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

  Future<void> _syncAllReminders() async {
    if (_isManagingReminders) {
      return;
    }

    setState(() => _isManagingReminders = true);
    try {
      await ref.read(reminderSyncControllerProvider).syncAll();
      ref.invalidate(pendingReminderCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已重新同步本地提醒')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('同步提醒失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isManagingReminders = false);
      }
    }
  }

  Future<void> _clearAllReminders() async {
    if (_isManagingReminders) {
      return;
    }

    setState(() => _isManagingReminders = true);
    try {
      await ref.read(reminderSyncControllerProvider).clearAll();
      ref.invalidate(pendingReminderCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清空本地提醒')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('清空提醒失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isManagingReminders = false);
      }
    }
  }
}

class _HabitSummaryCard extends StatelessWidget {
  const _HabitSummaryCard({
    required this.summary,
    required this.onTapAll,
    required this.onTapActive,
    required this.onTapCheckedToday,
  });

  final AsyncValue<HabitSummary> summary;
  final VoidCallback onTapAll;
  final VoidCallback onTapActive;
  final VoidCallback onTapCheckedToday;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: summary.when(
          data: (value) => Row(
            children: <Widget>[
              Expanded(
                child: _HabitMetric(
                  label: '总数',
                  value: value.total.toString(),
                  color: Theme.of(context).colorScheme.primary,
                  onTap: onTapAll,
                ),
              ),
              Expanded(
                child: _HabitMetric(
                  label: '进行中',
                  value: value.active.toString(),
                  color: const Color(0xFF136F63),
                  onTap: onTapActive,
                ),
              ),
              Expanded(
                child: _HabitMetric(
                  label: '今天已打卡',
                  value: value.checkedToday.toString(),
                  color: const Color(0xFFC06C00),
                  onTap: onTapCheckedToday,
                ),
              ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text('习惯统计加载失败：$error'),
        ),
      ),
    );
  }
}

class _HabitMetric extends StatelessWidget {
  const _HabitMetric({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
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
        ),
      ),
    );
  }
}

class _ReminderManagementCard extends StatelessWidget {
  const _ReminderManagementCard({
    required this.pendingReminderCount,
    required this.isBusy,
    required this.onSyncAll,
    required this.onClearAll,
  });

  final AsyncValue<int> pendingReminderCount;
  final bool isBusy;
  final Future<void> Function() onSyncAll;
  final Future<void> Function() onClearAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('本地提醒管理', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            pendingReminderCount.when(
              data: (count) => Text('当前待触发提醒：$count'),
              loading: () => const Text('正在读取提醒状态...'),
              error: (error, stackTrace) => Text('提醒状态读取失败：$error'),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: isBusy ? null : onSyncAll,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('重新同步提醒'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onClearAll,
                  icon: const Icon(Icons.notifications_off_outlined),
                  label: const Text('清空提醒'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCreateCard extends StatelessWidget {
  const _HabitCreateCard({
    required this.controller,
    required this.isCreating,
    required this.selectedReminder,
    required this.customReminderLabel,
    required this.selectedGoalId,
    required this.progressWeight,
    required this.goalOptions,
    required this.onReminderChanged,
    required this.onGoalChanged,
    required this.onProgressWeightChanged,
    required this.onPickCustomTime,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isCreating;
  final HabitReminderPreset selectedReminder;
  final String customReminderLabel;
  final String? selectedGoalId;
  final double progressWeight;
  final AsyncValue<List<GoalsTableData>> goalOptions;
  final ValueChanged<HabitReminderPreset> onReminderChanged;
  final ValueChanged<String?> onGoalChanged;
  final ValueChanged<double> onProgressWeightChanged;
  final Future<void> Function() onPickCustomTime;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('快速新增习惯', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !isCreating,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: '输入习惯名称，例如：晚间复盘',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
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
            if (selectedGoalId != null) ...<Widget>[
              const SizedBox(height: 12),
              Text('目标进度权重 ${progressWeight.toStringAsFixed(1)}'),
              Slider(
                value: progressWeight,
                min: 0.1,
                max: 2,
                divisions: 19,
                onChanged: isCreating ? null : onProgressWeightChanged,
              ),
            ],
            const SizedBox(height: 12),
            Text('提醒时间', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HabitReminderPreset.values.map((preset) {
                return ChoiceChip(
                  label: Text(preset.label),
                  selected: preset == selectedReminder,
                  onSelected: isCreating
                      ? null
                      : (_) => onReminderChanged(preset),
                );
              }).toList(),
            ),
            if (selectedReminder == HabitReminderPreset.custom) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isCreating ? null : onPickCustomTime,
                icon: const Icon(Icons.access_time_outlined),
                label: Text(customReminderLabel),
              ),
            ],
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
                label: Text(isCreating ? '保存中' : '新增习惯'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitListItem extends StatelessWidget {
  const _HabitListItem({
    required this.item,
    required this.isPending,
    required this.onChanged,
    required this.onOpenDetail,
    required this.onEdit,
  });

  final HabitTodayItem item;
  final bool isPending;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isPaused = item.habit.status == 'paused';
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
                  value: item.checkedToday,
                  onChanged: isPending || isPaused ? null : onChanged,
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
                            item.habit.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
                        _HabitTag(
                          label: item.checkedToday ? '今天已打卡' : '今天未打卡',
                          color: item.checkedToday
                              ? const Color(0xFF136F63)
                              : const Color(0xFFC06C00),
                        ),
                        if (item.habit.reminderTime != null)
                          _HabitTag(
                            label: '提醒 ${item.habit.reminderTime}',
                            color: const Color(0xFF607D8B),
                          ),
                        if (item.habit.goalId != null)
                          const _HabitTag(
                            label: '已关联目标',
                            color: Color(0xFF8A5CF6),
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
}

class _HabitTag extends StatelessWidget {
  const _HabitTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmptyHabitState extends StatelessWidget {
  const _EmptyHabitState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.bolt_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('还没有习惯', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '先新增一个习惯，页面会自动开始记录今天的打卡状态。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitErrorCard extends StatelessWidget {
  const _HabitErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}
