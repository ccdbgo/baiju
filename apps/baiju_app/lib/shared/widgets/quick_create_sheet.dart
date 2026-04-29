import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

Future<String?> showQuickCreateSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _QuickCreateSheet(),
  );
}

enum _QuickCreateType {
  todo(
    label: '待办',
    inputLabel: '待办标题',
    placeholder: '例如：整理本周会议纪要',
    submitLabel: '新增待办',
    successMessage: '已新增待办',
    emptyMessage: '请输入待办标题',
  ),
  schedule(
    label: '日程',
    inputLabel: '日程标题',
    placeholder: '例如：产品评审会',
    submitLabel: '新增日程',
    successMessage: '已新增日程',
    emptyMessage: '请输入日程标题',
  ),
  habit(
    label: '习惯',
    inputLabel: '习惯名称',
    placeholder: '例如：晚饭后散步 20 分钟',
    submitLabel: '新增习惯',
    successMessage: '已新增习惯',
    emptyMessage: '请输入习惯名称',
  ),
  anniversary(
    label: '纪念日',
    inputLabel: '纪念日标题',
    placeholder: '例如：入职纪念日',
    submitLabel: '新增纪念日',
    successMessage: '已新增纪念日',
    emptyMessage: '请输入纪念日标题',
  ),
  goal(
    label: '目标',
    inputLabel: '目标标题',
    placeholder: '例如：完成第二季度产品上线',
    submitLabel: '新增目标',
    successMessage: '已新增目标',
    emptyMessage: '请输入目标标题',
  ),
  note(
    label: '笔记',
    inputLabel: '笔记标题',
    placeholder: '例如：今天的复盘',
    submitLabel: '新增笔记',
    successMessage: '已新增笔记',
    emptyMessage: '请输入标题或内容',
  );

  const _QuickCreateType({
    required this.label,
    required this.inputLabel,
    required this.placeholder,
    required this.submitLabel,
    required this.successMessage,
    required this.emptyMessage,
  });

  final String label;
  final String inputLabel;
  final String placeholder;
  final String submitLabel;
  final String successMessage;
  final String emptyMessage;
}

class _QuickCreateSheet extends ConsumerStatefulWidget {
  const _QuickCreateSheet();

  @override
  ConsumerState<_QuickCreateSheet> createState() => _QuickCreateSheetState();
}

class _QuickCreateSheetState extends ConsumerState<_QuickCreateSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();

  _QuickCreateType _selectedType = _QuickCreateType.todo;
  TodoPriority _todoPriority = TodoPriority.notUrgentImportant;
  String? _todoGoalId;
  bool _todoDueToday = true;

  QuickScheduleDay _scheduleDay = QuickScheduleDay.today;
  QuickScheduleSlot _scheduleSlot = QuickScheduleSlot.morning;
  ScheduleDurationOption _scheduleDuration = ScheduleDurationOption.oneHour;
  late ScheduleReminderOption _scheduleReminder;

  HabitReminderPreset _habitReminderPreset = HabitReminderPreset.none;
  String? _habitGoalId;

  DateTime _anniversaryDate = DateTime.now();
  AnniversaryReminderOption _anniversaryReminder =
      AnniversaryReminderOption.three;

  GoalType _goalType = GoalType.stage;
  GoalProgressMode _goalProgressMode = GoalProgressMode.mixed;
  double _goalTodoWeight = 0.7;
  double _goalTodoUnitWeight = 1.0;
  double _goalHabitUnitWeight = 0.5;

  NoteType _noteType = NoteType.note;
  bool _noteIsFavorite = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _scheduleReminder = ref
        .read(userPreferencesProvider)
        .maybeWhen(
          data: (value) => value.defaultScheduleReminderOption,
          orElse: () => const UserPreferences().defaultScheduleReminderOption,
        );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalOptions = ref.watch(goalOptionsProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Text('快速新增', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('从任意页面直接写入当前工作区的数据流。', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _QuickCreateType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.label),
                  selected: type == _selectedType,
                  onSelected: _isSubmitting
                      ? null
                      : (_) => setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              enabled: !_isSubmitting,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: _selectedType.inputLabel,
                hintText: _selectedType.placeholder,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            _buildTypeFields(goalOptions),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(
                      _isSubmitting ? '保存中' : _selectedType.submitLabel,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFields(AsyncValue<List<GoalsTableData>> goalOptions) {
    return switch (_selectedType) {
      _QuickCreateType.todo => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ChoiceGroup<TodoPriority>(
            title: '优先级',
            value: _todoPriority,
            values: TodoPriority.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _todoPriority = value),
          ),
          _GoalDropdownField(
            goalOptions: goalOptions,
            selectedGoalId: _todoGoalId,
            enabled: !_isSubmitting,
            labelText: '关联目标',
            onChanged: (value) => setState(() => _todoGoalId = value),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _todoDueToday,
            contentPadding: EdgeInsets.zero,
            title: const Text('今天处理'),
            subtitle: const Text('会写入今天的截止时间'),
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _todoDueToday = value),
          ),
        ],
      ),
      _QuickCreateType.schedule => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ChoiceGroup<QuickScheduleDay>(
            title: '安排日期',
            value: _scheduleDay,
            values: QuickScheduleDay.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _scheduleDay = value),
          ),
          _ChoiceGroup<QuickScheduleSlot>(
            title: '开始时间',
            value: _scheduleSlot,
            values: QuickScheduleSlot.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _scheduleSlot = value),
          ),
          _ChoiceGroup<ScheduleDurationOption>(
            title: '时长',
            value: _scheduleDuration,
            values: ScheduleDurationOption.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _scheduleDuration = value),
          ),
          _ChoiceGroup<ScheduleReminderOption>(
            title: '提醒时间',
            value: _scheduleReminder,
            values: ScheduleReminderOption.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _scheduleReminder = value),
          ),
        ],
      ),
      _QuickCreateType.habit => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ChoiceGroup<HabitReminderPreset>(
            title: '提醒预设',
            value: _habitReminderPreset,
            values: const <HabitReminderPreset>[
              HabitReminderPreset.none,
              HabitReminderPreset.morning,
              HabitReminderPreset.evening,
            ],
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _habitReminderPreset = value),
          ),
          _GoalDropdownField(
            goalOptions: goalOptions,
            selectedGoalId: _habitGoalId,
            enabled: !_isSubmitting,
            labelText: '关联目标',
            onChanged: (value) => setState(() => _habitGoalId = value),
          ),
        ],
      ),
      _QuickCreateType.anniversary => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _anniversaryDate,
                          firstDate: DateTime(1970),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _anniversaryDate = picked);
                        }
                      },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(DateFormat('M月d日').format(_anniversaryDate)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ChoiceGroup<AnniversaryReminderOption>(
            title: '提醒时间',
            value: _anniversaryReminder,
            values: AnniversaryReminderOption.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _anniversaryReminder = value),
          ),
        ],
      ),
      _QuickCreateType.goal => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ChoiceGroup<GoalType>(
            title: '目标类型',
            value: _goalType,
            values: GoalType.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _goalType = value),
          ),
          _ChoiceGroup<GoalProgressMode>(
            title: '进度规则',
            value: _goalProgressMode,
            values: GoalProgressMode.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _goalProgressMode = value),
          ),
          if (_goalProgressMode == GoalProgressMode.weightedMixed) ...<Widget>[
            Text(
              '组权重：待办 ${(_goalTodoWeight * 100).round()}% / 习惯 ${((1 - _goalTodoWeight) * 100).round()}%',
            ),
            Slider(
              value: _goalTodoWeight,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _goalTodoWeight = value),
            ),
            Text('待办单次完成权重 ${_goalTodoUnitWeight.toStringAsFixed(1)}'),
            Slider(
              value: _goalTodoUnitWeight,
              min: 0.1,
              max: 2,
              divisions: 19,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _goalTodoUnitWeight = value),
            ),
            Text('习惯单次打卡权重 ${_goalHabitUnitWeight.toStringAsFixed(1)}'),
            Slider(
              value: _goalHabitUnitWeight,
              min: 0.1,
              max: 2,
              divisions: 19,
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _goalHabitUnitWeight = value),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _targetController,
                  enabled: !_isSubmitting,
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
                  controller: _unitController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: '单位',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      _QuickCreateType.note => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _contentController,
            enabled: !_isSubmitting,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '内容',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _ChoiceGroup<NoteType>(
            title: '类型',
            value: _noteType,
            values: NoteType.values,
            enabled: !_isSubmitting,
            labelBuilder: (value) => value.label,
            onChanged: (value) => setState(() => _noteType = value),
          ),
          SwitchListTile(
            value: _noteIsFavorite,
            contentPadding: EdgeInsets.zero,
            title: const Text('创建时直接收藏'),
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _noteIsFavorite = value),
          ),
        ],
      ),
    };
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (_isSubmitting) {
      return;
    }

    final noteContent = _contentController.text.trim();
    final requiresNotePayload = _selectedType == _QuickCreateType.note;
    if (requiresNotePayload
        ? title.isEmpty && noteContent.isEmpty
        : title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_selectedType.emptyMessage)));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      switch (_selectedType) {
        case _QuickCreateType.todo:
          await ref
              .read(todoActionsProvider)
              .createTodo(
                title: title,
                priority: _todoPriority,
                dueToday: _todoDueToday,
                goalId: _todoGoalId,
              );
          break;
        case _QuickCreateType.schedule:
          await ref
              .read(scheduleActionsProvider)
              .createSchedule(
                title: title,
                day: _scheduleDay,
                slot: _scheduleSlot,
                duration: _scheduleDuration,
                reminder: _scheduleReminder,
              );
          break;
        case _QuickCreateType.habit:
          await ref
              .read(habitActionsProvider)
              .createHabit(
                name: title,
                reminderTime: _habitReminderPreset.value,
                goalId: _habitGoalId,
              );
          break;
        case _QuickCreateType.anniversary:
          await ref
              .read(anniversaryActionsProvider)
              .createAnniversary(
                title: title,
                baseDate: _anniversaryDate,
                reminder: _anniversaryReminder,
              );
          break;
        case _QuickCreateType.goal:
          await ref
              .read(goalActionsProvider)
              .createGoal(
                title: title,
                goalType: _goalType,
                progressMode: _goalProgressMode,
                todoWeight: _goalTodoWeight,
                habitWeight: (1 - _goalTodoWeight).toDouble(),
                todoUnitWeight: _goalTodoUnitWeight,
                habitUnitWeight: _goalHabitUnitWeight,
                progressTarget: double.tryParse(_targetController.text.trim()),
                unit: _unitController.text.trim().isEmpty
                    ? null
                    : _unitController.text.trim(),
              );
          break;
        case _QuickCreateType.note:
          await ref
              .read(noteActionsProvider)
              .createNote(
                title: title,
                content: noteContent,
                noteType: _noteType,
                isFavorite: _noteIsFavorite,
              );
          break;
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(_selectedType.successMessage);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedType.submitLabel}失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.value,
    required this.values,
    required this.enabled,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final bool enabled;
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
              onSelected: enabled ? (_) => onChanged(item) : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _GoalDropdownField extends StatelessWidget {
  const _GoalDropdownField({
    required this.goalOptions,
    required this.selectedGoalId,
    required this.enabled,
    required this.labelText,
    required this.onChanged,
  });

  final AsyncValue<List<GoalsTableData>> goalOptions;
  final String? selectedGoalId;
  final bool enabled;
  final String labelText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return goalOptions.when(
      data: (goals) => DropdownButtonFormField<String?>(
        key: ValueKey<String?>('$labelText-${selectedGoalId ?? 'none'}'),
        initialValue: selectedGoalId,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
        ),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(value: null, child: Text('不关联目标')),
          ...goals.map(
            (goal) => DropdownMenuItem<String?>(
              value: goal.id,
              child: Text(goal.title),
            ),
          ),
        ],
        onChanged: enabled ? onChanged : null,
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('目标加载失败：$error'),
      ),
    );
  }
}
