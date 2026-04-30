import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_editor_sheet.dart';
import 'package:baiju_app/features/note/presentation/widgets/related_notes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HabitDetailPage extends ConsumerWidget {
  const HabitDetailPage({required this.habitId, super.key});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = ref.watch(habitDetailProvider(habitId));
    final insights = ref.watch(habitDetailInsightsProvider(habitId));

    return Scaffold(
      appBar: AppBar(title: const Text('习惯详情')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: habit.when(
          data: (value) {
            if (value == null) {
              return const Center(child: Text('习惯不存在或已删除'));
            }

            final linkedGoal = value.goalId == null
                ? null
                : ref.watch(goalDetailProvider(value.goalId!));
            final relatedNotes = ref.watch(
              relatedNoteListProvider(
                NoteRelationTarget(entityType: 'habit', entityId: value.id),
              ),
            );

            return ListView(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        value.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openEditHabitSheet(context, ref, value),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DetailRow(label: '频率', value: value.frequencyType),
                _DetailRow(label: '状态', value: value.status),
                if (value.reminderTime != null)
                  _DetailRow(label: '提醒时间', value: value.reminderTime!),
                const SizedBox(height: 8),
                _HabitStatsSection(
                  insights: insights,
                  onBackfill: value.status == 'paused'
                      ? null
                      : () => _openBackfillSheet(context, ref, value),
                ),
                const SizedBox(height: 12),
                _HabitRecentRecordsSection(insights: insights),
                const SizedBox(height: 12),
                if (linkedGoal != null) ...<Widget>[
                  Text('关联对象', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                ],
                RelatedNotesSection(
                  relatedNotes: relatedNotes,
                  onCreate: () => _createRelatedNote(context, ref, value),
                  onOpenNote: (note) => context.push('/note/${note.id}'),
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: '目标进度权重',
                  value: value.progressWeight.toStringAsFixed(1),
                ),
                const SizedBox(height: 12),
                Text('状态操作', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _togglePauseHabit(context, ref, value),
                      icon: Icon(
                        value.status == 'paused'
                            ? Icons.play_arrow_outlined
                            : Icons.pause_outlined,
                      ),
                      label: Text(value.status == 'paused' ? '恢复' : '暂停'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _deleteHabit(context, ref, value),
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

  Future<void> _openEditHabitSheet(
    BuildContext context,
    WidgetRef ref,
    HabitsTableData habit,
  ) async {
    final controller = TextEditingController(text: habit.name);
    var selectedReminder = HabitReminderPreset.fromReminderTime(
      habit.reminderTime,
    );
    TimeOfDay? customReminder = _parseReminderTime(habit.reminderTime);
    var progressWeight = habit.progressWeight;

    try {
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
                child: SingleChildScrollView(
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
                      if (selectedReminder == HabitReminderPreset.custom) ...<Widget>[
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

      final reminderTime = switch (selectedReminder) {
        HabitReminderPreset.none => null,
        HabitReminderPreset.morning => HabitReminderPreset.morning.value,
        HabitReminderPreset.evening => HabitReminderPreset.evening.value,
        HabitReminderPreset.custom =>
          customReminder == null
              ? null
              : '${customReminder!.hour.toString().padLeft(2, '0')}:${customReminder!.minute.toString().padLeft(2, '0')}',
      };

      try {
        await ref.read(habitActionsProvider).updateHabit(
              habit: habit,
              name: controller.text.trim(),
              reminderTime: reminderTime,
              goalId: habit.goalId,
              progressWeight: progressWeight,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('习惯已更新')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败：$error')),
          );
        }
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openBackfillSheet(
    BuildContext context,
    WidgetRef ref,
    HabitsTableData habit,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      habit.startDate.toLocal().year,
      habit.startDate.toLocal().month,
      habit.startDate.toLocal().day,
    );
    final firstDate = startDate.isAfter(today) ? today : startDate;
    var selectedDate = today;
    var selectedStatus = HabitRecordStatus.done;
    var isSaving = false;

    final succeeded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
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
                    Text('补打卡', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      '可补记过去日期或今天，未来日期不可补记。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: firstDate,
                                lastDate: today,
                              );
                              if (picked != null) {
                                setModalState(() {
                                  selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                  );
                                });
                              }
                            },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('日期：${_formatDate(selectedDate)}'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <HabitRecordStatus>[
                        HabitRecordStatus.done,
                        HabitRecordStatus.skipped,
                      ].map((status) {
                        return ChoiceChip(
                          label: Text(status.label),
                          selected: selectedStatus == status,
                          onSelected: isSaving
                              ? null
                              : (_) => setModalState(() => selectedStatus = status),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  await ref.read(habitActionsProvider).backfillHabitRecord(
                                        habit: habit,
                                        recordDate: selectedDate,
                                        status: selectedStatus,
                                      );
                                  if (context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('补打卡失败：$error')),
                                    );
                                  }
                                } finally {
                                  if (context.mounted) {
                                    setModalState(() => isSaving = false);
                                  }
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.history_toggle_off_outlined),
                        label: Text(isSaving ? '保存中...' : '保存补打卡'),
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

    if (succeeded == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('补打卡已保存')));
    }
  }

  Future<void> _togglePauseHabit(
    BuildContext context,
    WidgetRef ref,
    HabitsTableData habit,
  ) async {
    final paused = habit.status != 'paused';
    final confirmed = await _confirmAction(
      context,
      title: paused ? '暂停这个习惯？' : '恢复这个习惯？',
      message: paused
          ? '暂停后将不允许继续打卡，并取消本地提醒。'
          : '恢复后会重新进入今日流程，并同步本地提醒。',
      confirmLabel: paused ? '暂停' : '恢复',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(habitActionsProvider).setHabitPaused(habit, paused);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(paused ? '习惯已暂停' : '习惯已恢复')));
  }

  Future<void> _createRelatedNote(
    BuildContext context,
    WidgetRef ref,
    HabitsTableData habit,
  ) async {
    final result = await showNoteEditorSheet(
      context,
      title: '新增关联笔记',
      confirmLabel: '保存笔记',
      initialTitle: habit.name,
    );
    if (result == null) {
      return;
    }

    await ref.read(noteActionsProvider).createNote(
          title: result.title,
          content: result.content,
          noteType: result.noteType,
          isFavorite: result.isFavorite,
          relatedEntityType: 'habit',
          relatedEntityId: habit.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关联笔记已创建')));
    }
  }

  Future<void> _deleteHabit(
    BuildContext context,
    WidgetRef ref,
    HabitsTableData habit,
  ) async {
    final confirmed = await _confirmAction(
      context,
      title: '删除这个习惯？',
      message: '删除后它会从今日和习惯列表中移除，并取消提醒。',
      confirmLabel: '删除',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(habitActionsProvider).deleteHabit(habit);
    if (!context.mounted) {
      return;
    }
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('习惯已删除')));
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

class _HabitStatsSection extends StatelessWidget {
  const _HabitStatsSection({
    required this.insights,
    required this.onBackfill,
  });

  final AsyncValue<HabitDetailInsights> insights;
  final VoidCallback? onBackfill;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: insights.when(
          data: (value) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('打卡统计', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatsMetric(
                        label: '连续打卡',
                        value: '${value.stats30Days.currentStreak} 天',
                        color: const Color(0xFF136F63),
                      ),
                    ),
                    Expanded(
                      child: _StatsMetric(
                        label: '近7天完成率',
                        value: value.stats7Days.completionRateLabel,
                        color: const Color(0xFFC06C00),
                      ),
                    ),
                    Expanded(
                      child: _StatsMetric(
                        label: '近30天完成率',
                        value: value.stats30Days.completionRateLabel,
                        color: const Color(0xFF607D8B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _HabitHeatmap(records: value.recentRecords),
                const SizedBox(height: 10),
                Text(
                  '规则：完成率 = 窗口内 done 天数 / 窗口总天数，未记录按未完成计算。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _SmallTag(label: '近7天：完成 ${value.stats7Days.doneDays} 天'),
                    _SmallTag(label: '近7天：跳过 ${value.stats7Days.skippedDays} 天'),
                    _SmallTag(label: '近30天最长连续 ${value.stats30Days.longestStreak} 天'),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onBackfill,
                  icon: const Icon(Icons.history_toggle_off_outlined),
                  label: const Text('补打卡'),
                ),
              ],
            );
          },
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

class _HabitRecentRecordsSection extends StatelessWidget {
  const _HabitRecentRecordsSection({required this.insights});

  final AsyncValue<HabitDetailInsights> insights;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: insights.when(
          data: (value) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('最近记录', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                ...value.recentRecords.take(10).map((item) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(_formatDate(item.date.toLocal())),
                    subtitle: Text('状态：${item.status.label}'),
                    trailing: _StatusChip(status: item.status),
                  );
                }),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text('最近记录加载失败：$error'),
        ),
      ),
    );
  }
}

class _StatsMetric extends StatelessWidget {
  const _StatsMetric({
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _HabitHeatmap extends StatelessWidget {
  const _HabitHeatmap({required this.records});

  final List<HabitRecordDayState> records;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Build a map of date -> status for quick lookup
    final statusMap = <DateTime, HabitRecordStatus>{};
    for (final r in records) {
      final d = r.date.toLocal();
      statusMap[DateTime(d.year, d.month, d.day)] = r.status;
    }

    // Last 35 days (5 rows × 7 cols), oldest first
    final days = List.generate(35, (i) {
      return todayDate.subtract(Duration(days: 34 - i));
    });

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('近35天打卡', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final day = days[index];
            final status = statusMap[day];
            Color cellColor;
            if (status == HabitRecordStatus.done) {
              cellColor = const Color(0xFF136F63);
            } else if (status == HabitRecordStatus.skipped) {
              cellColor = const Color(0xFFC06C00).withValues(alpha: 0.4);
            } else {
              cellColor = colorScheme.surfaceContainerHighest;
            }
            final isToday = day == todayDate;
            return Tooltip(
              message: '${day.month}/${day.day}',
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(3),
                  border: isToday
                      ? Border.all(color: colorScheme.primary, width: 1.5)
                      : null,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _HeatmapLegend(color: const Color(0xFF136F63), label: '完成'),
            const SizedBox(width: 12),
            _HeatmapLegend(
              color: const Color(0xFFC06C00).withValues(alpha: 0.4),
              label: '跳过',
            ),
            const SizedBox(width: 12),
            _HeatmapLegend(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              label: '未记录',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend({required this.color, required this.label});

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
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final HabitRecordStatus status;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    switch (status) {
      case HabitRecordStatus.done:
        background = const Color(0xFFE5F4EE);
        foreground = const Color(0xFF136F63);
        break;
      case HabitRecordStatus.skipped:
        background = const Color(0xFFFFF2DF);
        foreground = const Color(0xFFC06C00);
        break;
      case HabitRecordStatus.none:
        background = const Color(0xFFECEFF1);
        foreground = const Color(0xFF455A64);
        break;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          status.label,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w600,
          ),
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

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
