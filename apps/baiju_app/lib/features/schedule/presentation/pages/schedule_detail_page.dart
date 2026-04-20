import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_editor_sheet.dart';
import 'package:baiju_app/features/note/presentation/widgets/related_notes_section.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ScheduleDetailPage extends ConsumerWidget {
  const ScheduleDetailPage({required this.scheduleId, super.key});

  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(scheduleDetailProvider(scheduleId));

    return Scaffold(
      appBar: AppBar(title: const Text('日程详情')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: schedule.when(
          data: (value) {
            if (value == null) {
              return const Center(child: Text('日程不存在或已删除'));
            }
            final sourceTodo = value.sourceTodoId == null
                ? null
                : ref.watch(todoDetailProvider(value.sourceTodoId!));
            final relatedNotes = ref.watch(
              relatedNoteListProvider(
                NoteRelationTarget(entityType: 'schedule', entityId: value.id),
              ),
            );
            final localStart = value.startAt.toLocal();
            final localEnd = value.endAt.toLocal();
            final location = _normalizeOptionalText(value.location);
            final category = _normalizeOptionalText(value.category);
            final description = _normalizeOptionalText(value.description);
            final hasSupplementaryInfo =
                location != null || category != null || description != null;

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
                          _openEditScheduleSheet(context, ref, value),
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
                    _InlineInfoChip(
                      label: '状态：${_scheduleStatusLabel(value.status)}',
                    ),
                    _InlineInfoChip(label: value.isAllDay ? '全天' : '按时段'),
                    _InlineInfoChip(
                      label:
                          '重复：${ScheduleRecurrenceRule.fromRule(value.recurrenceRule).label}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _DetailSection(
                  title: '时间安排',
                  children: <Widget>[
                    _DetailRow(
                      label: '日期',
                      value: DateFormat('yyyy年M月d日').format(localStart),
                    ),
                    if (value.isAllDay)
                      const _DetailRow(label: '时段', value: '全天')
                    else ...<Widget>[
                      _DetailRow(
                        label: '开始时间',
                        value: DateFormat('yyyy年M月d日 HH:mm').format(localStart),
                      ),
                      _DetailRow(
                        label: '结束时间',
                        value: DateFormat('yyyy年M月d日 HH:mm').format(localEnd),
                      ),
                    ],
                    _DetailRow(
                      label: '提醒',
                      value: value.reminderMinutesBefore == null
                          ? '不提醒'
                          : '提前 ${value.reminderMinutesBefore} 分钟',
                    ),
                  ],
                ),
                if (hasSupplementaryInfo) ...<Widget>[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: '补充信息',
                    children: <Widget>[
                      if (location != null) _DetailRow(label: '地点', value: location),
                      if (category != null) _DetailRow(label: '分类', value: category),
                      if (description != null)
                        _DetailRow(label: '描述', value: description),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text('联动操作', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    OutlinedButton.icon(
                      key: const ValueKey(
                        'schedule-detail-action-convert-to-todo',
                      ),
                      onPressed: () => _convertScheduleToTodo(context, ref, value),
                      icon: const Icon(Icons.task_alt_outlined),
                      label: const Text('转成待办'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey(
                        'schedule-detail-action-sync-habit-record',
                      ),
                      onPressed: () => _syncToHabitRecord(context, ref, value),
                      icon: const Icon(Icons.auto_graph_outlined),
                      label: const Text('同步为打卡记录'),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('schedule-detail-action-postpone'),
                      onPressed: value.status == 'planned'
                          ? () => _postponeScheduleByOneDay(context, ref, value)
                          : null,
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: const Text('顺延一天'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sourceTodo != null) ...<Widget>[
                  Text('关联对象', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  sourceTodo.when(
                    data: (todo) => _LinkedObjectTile(
                      label: '来源待办',
                      title: todo?.title ?? value.sourceTodoId!,
                      icon: Icons.checklist_outlined,
                      onTap: todo == null
                          ? null
                          : () => context.push('/todo/${todo.id}'),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => Text('来源待办加载失败：$error'),
                  ),
                  const SizedBox(height: 12),
                ],
                RelatedNotesSection(
                  relatedNotes: relatedNotes,
                  onCreate: () => _createRelatedNote(context, ref, value),
                  onOpenNote: (note) => context.push('/note/${note.id}'),
                ),
                const SizedBox(height: 12),
                Text('状态操作', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    if (value.status != 'cancelled' &&
                        value.status != 'completed')
                      OutlinedButton.icon(
                        onPressed: () => _cancelSchedule(context, ref, value),
                        icon: const Icon(Icons.event_busy_outlined),
                        label: const Text('取消'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _deleteSchedule(context, ref, value),
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

  Future<void> _openEditScheduleSheet(
    BuildContext context,
    WidgetRef ref,
    SchedulesTableData schedule,
  ) async {
    final controller = TextEditingController(text: schedule.title);
    final locationController = TextEditingController(text: schedule.location);
    final categoryController = TextEditingController(text: schedule.category);
    final descriptionController = TextEditingController(
      text: schedule.description,
    );
    var selectedDate = schedule.startAt.toLocal();
    var selectedTime = TimeOfDay.fromDateTime(schedule.startAt.toLocal());
    var selectedDuration = _durationFromSchedule(schedule);
    var isAllDay = schedule.isAllDay;
    var selectedReminder = ScheduleReminderOption.fromMinutes(
      schedule.reminderMinutesBefore,
    );
    var selectedRecurrence = ScheduleRecurrenceRule.fromRule(
      schedule.recurrenceRule,
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    20 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '编辑日程',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: '标题',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        value: isAllDay,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('全天'),
                        subtitle: const Text('全天日程不展示具体时段'),
                        onChanged: (value) =>
                            setModalState(() => isAllDay = value),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                                initialDate: selectedDate,
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
                          if (!isAllDay)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setModalState(() => selectedTime = picked);
                                }
                              },
                              icon: const Icon(Icons.schedule),
                              label: Text(selectedTime.format(context)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isAllDay)
                        _ChoiceGroup<ScheduleDurationOption>(
                          title: '时长',
                          value: selectedDuration,
                          values: ScheduleDurationOption.values,
                          labelBuilder: (value) => value.label,
                          onChanged: (value) =>
                              setModalState(() => selectedDuration = value),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '全天默认占用所选日期 00:00 - 次日 00:00。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      TextField(
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: '地点',
                          hintText: '例如：会议室 A / 线上会议',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          hintText: '例如：工作、学习、生活',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '描述（可选）',
                          hintText: '补充这条安排的背景或注意事项',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ChoiceGroup<ScheduleReminderOption>(
                        title: '提醒时间',
                        value: selectedReminder,
                        values: ScheduleReminderOption.values,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) =>
                            setModalState(() => selectedReminder = value),
                      ),
                      _ChoiceGroup<ScheduleRecurrenceRule>(
                        title: '重复规则',
                        value: selectedRecurrence,
                        values: ScheduleRecurrenceRule.presets,
                        labelBuilder: (value) => value.label,
                        onChanged: (value) =>
                            setModalState(() => selectedRecurrence = value),
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

      final localStart = isAllDay
          ? DateTime(selectedDate.year, selectedDate.month, selectedDate.day)
          : DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );
      final localEnd = isAllDay
          ? localStart.add(const Duration(days: 1))
          : localStart.add(Duration(minutes: selectedDuration.minutes));

      await ref.read(scheduleActionsProvider).updateSchedule(
        schedule: schedule,
        title: controller.text.trim(),
        startAt: localStart.toUtc(),
        endAt: localEnd.toUtc(),
        reminder: selectedReminder,
        recurrence: selectedRecurrence,
        description: descriptionController.text,
        location: locationController.text,
        category: categoryController.text,
        isAllDay: isAllDay,
      );
    } finally {
      controller.dispose();
      locationController.dispose();
      categoryController.dispose();
      descriptionController.dispose();
    }
  }

  String? _normalizeOptionalText(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _scheduleStatusLabel(String status) {
    return switch (status) {
      'planned' => '待进行',
      'completed' => '已完成',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  Future<void> _convertScheduleToTodo(
    BuildContext context,
    WidgetRef ref,
    SchedulesTableData schedule,
  ) async {
    try {
      await ref
          .read(scheduleActionsProvider)
          .convertScheduleToTodo(schedule: schedule);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已将日程转成待办')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转待办失败：$error')),
      );
    }
  }

  Future<void> _syncToHabitRecord(
    BuildContext context,
    WidgetRef ref,
    SchedulesTableData schedule,
  ) async {
    // Let the user pick which habit to sync to
    final habits = await ref.read(habitListProvider.future);
    if (!context.mounted) return;

    if (habits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('还没有习惯，请先创建一个习惯')),
      );
      return;
    }

    HabitsTableData? selectedHabit;
    if (habits.length == 1) {
      selectedHabit = habits.first.habit;
    } else {
      selectedHabit = await showDialog<HabitsTableData>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择要打卡的习惯'),
          children: habits.map((item) {
            return SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(item.habit),
              child: Text(item.habit.name),
            );
          }).toList(),
        ),
      );
    }

    if (selectedHabit == null) return;

    try {
      await ref.read(scheduleActionsProvider).syncScheduleToHabitRecord(
        schedule: schedule,
        habit: selectedHabit,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已同步为打卡记录')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步打卡失败：$error')),
      );
    }
  }

  Future<void> _postponeScheduleByOneDay(
    BuildContext context,
    WidgetRef ref,
    SchedulesTableData schedule,
  ) async {
    try {
      await ref
          .read(scheduleActionsProvider)
          .postponeSchedule(schedule: schedule, days: 1);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已将日程顺延一天')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('延期失败：$error')),
      );
    }
  }

  Future<void> _cancelSchedule(
    BuildContext context,
    WidgetRef ref,
    SchedulesTableData schedule,
  ) async {
    final confirmed = await _confirmAction(
      context,
      title: '取消这条日程？',
      message: '取消后它会从今日和待进行日程中移除，并取消本地提醒。',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(scheduleActionsProvider).cancelSchedule(schedule);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日程已取消')));
  }

  Future<void> _createRelatedNote(
    BuildContext context,
    WidgetRef ref,
    SchedulesTableData schedule,
  ) async {
    final result = await showNoteEditorSheet(
      context,
      title: '新增关联笔记',
      confirmLabel: '保存笔记',
      initialTitle: schedule.title,
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
          relatedEntityType: 'schedule',
          relatedEntityId: schedule.id,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('关联笔记已创建')));
    }
  }

  Future<void> _deleteSchedule(
    BuildContext context,
    WidgetRef ref,
    SchedulesTableData schedule,
  ) async {
    final confirmed = await _confirmAction(
      context,
      title: '删除这条日程？',
      message: '删除后会移除该日程并取消提醒，时间线中会保留删除记录。',
      confirmLabel: '删除',
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(scheduleActionsProvider).deleteSchedule(schedule);
    if (!context.mounted) {
      return;
    }
    context.pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日程已删除')));
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

  ScheduleDurationOption _durationFromSchedule(SchedulesTableData schedule) {
    final minutes = schedule.endAt.difference(schedule.startAt).inMinutes;
    return ScheduleDurationOption.values.firstWhere(
      (option) => option.minutes == minutes,
      orElse: () => ScheduleDurationOption.oneHour,
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InlineInfoChip extends StatelessWidget {
  const _InlineInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
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
