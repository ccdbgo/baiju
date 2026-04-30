import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/schedule/presentation/widgets/schedule_calendar_views.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum ScheduleSortOption {
  startAsc('开始时间'),
  updatedDesc('最近更新'),
  reminderFirst('提醒优先');

  const ScheduleSortOption(this.label);

  final String label;
}

enum ScheduleAllDayFilterOption {
  all('全部日程'),
  allDay('仅全天'),
  timed('仅分时段');

  const ScheduleAllDayFilterOption(this.label);

  final String label;
}

class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _pendingScheduleIds = <String>{};

  ScheduleViewMode _selectedView = ScheduleViewMode.day;
  ScheduleSortOption _sortOption = ScheduleSortOption.startAsc;
  ScheduleAllDayFilterOption _allDayFilterOption =
      ScheduleAllDayFilterOption.all;
  DateTime _focusDate = DateTime.now();
  String? _selectedCategoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(scheduleSummaryProvider);
    final schedules = ref.watch(scheduleListProvider);
    final allSchedules = ref.watch(allScheduleListProvider);
    final selectedFilter = ref.watch(selectedScheduleFilterProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('日程', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '管理你的时间安排，支持日/周/月/年视图和提醒。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _ScheduleSummaryCard(
            summary: summary,
            onTapAll: () => ref.read(selectedScheduleFilterProvider.notifier).select(ScheduleFilter.all),
            onTapToday: () => ref.read(selectedScheduleFilterProvider.notifier).select(ScheduleFilter.today),
            onTapUpcoming: () => ref.read(selectedScheduleFilterProvider.notifier).select(ScheduleFilter.upcoming),
            onTapCompleted: () => ref.read(selectedScheduleFilterProvider.notifier).select(ScheduleFilter.completed),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ScheduleViewMode>(
            segments: ScheduleViewMode.values
                .map(
                  (mode) => ButtonSegment<ScheduleViewMode>(
                    value: mode,
                    label: Text(mode.label),
                    icon: Icon(mode.icon),
                  ),
                )
                .toList(),
            selected: <ScheduleViewMode>{_selectedView},
            onSelectionChanged: (selection) {
              setState(() => _selectedView = selection.first);
            },
          ),
          const SizedBox(height: 12),
          ViewHeader(
            selectedView: _selectedView,
            focusDate: _focusDate,
            onPrevious: _moveFocusBackward,
            onToday: () => setState(() => _focusDate = DateTime.now()),
            onNext: _moveFocusForward,
          ),
          const SizedBox(height: 12),
          allSchedules.when(
            data: (items) => ScheduleViewCard(
              selectedView: _selectedView,
              focusDate: _focusDate,
              schedules: items,
              pendingScheduleIds: _pendingScheduleIds,
              onToggleSchedule: _toggleSchedule,
              onOpenScheduleDetail: (schedule) =>
                  context.push('/schedule/${schedule.id}'),
              onSelectDate: (date) {
                setState(() {
                  _focusDate = date;
                  _selectedView = ScheduleViewMode.day;
                });
              },
              onSelectMonth: (monthDate) {
                setState(() {
                  _focusDate = monthDate;
                  _selectedView = ScheduleViewMode.month;
                });
              },
              onRequestCreate: (startAt, endAt, isAllDay) =>
                  _openCreateScheduleSheet(
                    startAt: startAt,
                    endAt: endAt,
                    isAllDay: isAllDay,
                  ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('视图加载失败：$error'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ScheduleFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(filter.label),
                selected: filter == selectedFilter,
                onSelected: (_) {
                  ref
                      .read(selectedScheduleFilterProvider.notifier)
                      .select(filter);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          ModuleSearchField(
            key: const ValueKey('schedule-search-field'),
            controller: _searchController,
            labelText: '搜索日程',
            hintText: '标题 / 地点 / 分类 / 描述',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          schedules.when(
            data: (items) {
              if (items.isEmpty) {
                return _EmptyScheduleState(filter: selectedFilter);
              }

              final categoryOptions = _categoryOptions(items);
              final activeCategoryFilter =
                  categoryOptions.contains(_selectedCategoryFilter)
                  ? _selectedCategoryFilter
                  : null;
              final normalizedSearch = _searchController.text
                  .trim()
                  .toLowerCase();
              final filtered = items.where((schedule) {
                if (!_matchesSearch(schedule, normalizedSearch)) {
                  return false;
                }
                if (!_matchesAllDayFilter(schedule, _allDayFilterOption)) {
                  return false;
                }
                if (activeCategoryFilter != null) {
                  return schedule.category?.trim() == activeCategoryFilter;
                }
                return true;
              }).toList();

              final sorted = filtered.toList()
                ..sort((left, right) {
                  switch (_sortOption) {
                    case ScheduleSortOption.startAsc:
                      return left.startAt.compareTo(right.startAt);
                    case ScheduleSortOption.updatedDesc:
                      return right.updatedAt.compareTo(left.updatedAt);
                    case ScheduleSortOption.reminderFirst:
                      final leftReminder = left.reminderMinutesBefore ?? 9999;
                      final rightReminder = right.reminderMinutesBefore ?? 9999;
                      final diff = leftReminder.compareTo(rightReminder);
                      if (diff != 0) {
                        return diff;
                      }
                      return left.startAt.compareTo(right.startAt);
                  }
                });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ScheduleSearchFilterBar(
                    allDayFilterOption: _allDayFilterOption,
                    selectedCategory: activeCategoryFilter,
                    categoryOptions: categoryOptions,
                    onAllDayFilterSelected: (value) =>
                        setState(() => _allDayFilterOption = value),
                    onCategorySelected: (value) =>
                        setState(() => _selectedCategoryFilter = value),
                  ),
                  const SizedBox(height: 12),
                  SelectionChipBar<ScheduleSortOption>(
                    values: ScheduleSortOption.values,
                    selected: _sortOption,
                    labelBuilder: (option) => option.label,
                    onSelected: (option) =>
                        setState(() => _sortOption = option),
                  ),
                  const SizedBox(height: 16),
                  if (sorted.isEmpty)
                    const _ScheduleErrorCard(message: '当前筛选条件下没有日程。')
                  else
                    Column(
                      children: sorted
                          .map(
                            (schedule) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ScheduleListItem(
                                schedule: schedule,
                                isPending: _pendingScheduleIds.contains(
                                  schedule.id,
                                ),
                                onChanged: (value) =>
                                    _toggleSchedule(schedule, value ?? false),
                                onOpenDetail: () =>
                                    context.push('/schedule/${schedule.id}'),
                                onEdit: () => _openEditScheduleSheet(schedule),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                _ScheduleErrorCard(message: '日程列表加载失败：$error'),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(SchedulesTableData schedule, String normalizedSearch) {
    if (normalizedSearch.isEmpty) {
      return true;
    }
    final searchableFields = <String>[
      schedule.title,
      schedule.location ?? '',
      schedule.category ?? '',
      schedule.description ?? '',
    ];
    return searchableFields.any(
      (field) => field.toLowerCase().contains(normalizedSearch),
    );
  }

  bool _matchesAllDayFilter(
    SchedulesTableData schedule,
    ScheduleAllDayFilterOption filterOption,
  ) {
    return switch (filterOption) {
      ScheduleAllDayFilterOption.all => true,
      ScheduleAllDayFilterOption.allDay => schedule.isAllDay,
      ScheduleAllDayFilterOption.timed => !schedule.isAllDay,
    };
  }

  List<String> _categoryOptions(List<SchedulesTableData> schedules) {
    final categories = schedules
        .map((schedule) => schedule.category?.trim())
        .whereType<String>()
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return categories;
  }

  Future<void> _toggleSchedule(
    SchedulesTableData schedule,
    bool completed,
  ) async {
    if (_pendingScheduleIds.contains(schedule.id)) {
      return;
    }

    setState(() => _pendingScheduleIds.add(schedule.id));
    try {
      await ref
          .read(scheduleActionsProvider)
          .toggleScheduleCompletion(schedule, completed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新日程状态失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingScheduleIds.remove(schedule.id));
      }
    }
  }

  Future<void> _openEditScheduleSheet(SchedulesTableData schedule) async {
    final controller = TextEditingController(text: schedule.title);
    final locationController = TextEditingController(text: schedule.location);
    final categoryController = TextEditingController(text: schedule.category);
    final descriptionController = TextEditingController(
      text: schedule.description,
    );
    var selectedStartAt = schedule.startAt.toLocal();
    var selectedEndAt = schedule.endAt.toLocal();
    var isAllDay = schedule.isAllDay;
    var selectedReminder = ScheduleReminderOption.fromMinutes(
      schedule.reminderMinutesBefore,
    );
    var selectedRecurrence = ScheduleRecurrenceRule.fromRule(
      schedule.recurrenceRule,
    );
    var selectedPriority = TodoPriority.fromValue(schedule.priority);

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDateTime({required bool isStart}) async {
                final current = isStart ? selectedStartAt : selectedEndAt;
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  initialDate: current,
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(current),
                );
                if (time == null) return;
                final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                setModalState(() {
                  if (isStart) {
                    selectedStartAt = picked;
                    if (!selectedEndAt.isAfter(selectedStartAt)) {
                      selectedEndAt = selectedStartAt.add(const Duration(hours: 1));
                    }
                  } else {
                    selectedEndAt = picked;
                  }
                });
              }

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
                        key: const ValueKey('schedule-edit-is-all-day-switch'),
                        value: isAllDay,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('全天'),
                        subtitle: const Text('全天日程不显示具体时段'),
                        onChanged: (value) =>
                            setModalState(() => isAllDay = value),
                      ),
                      const SizedBox(height: 6),
                      if (!isAllDay) ...<Widget>[
                        OutlinedButton.icon(
                          onPressed: () => pickDateTime(isStart: true),
                          icon: const Icon(Icons.schedule, size: 16),
                          label: Text(
                            '开始：${DateFormat('M月d日 HH:mm').format(selectedStartAt)}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => pickDateTime(isStart: false),
                          icon: const Icon(Icons.schedule_outlined, size: 16),
                          label: Text(
                            '结束：${DateFormat('M月d日 HH:mm').format(selectedEndAt)}',
                          ),
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              initialDate: selectedStartAt,
                            );
                            if (picked != null) {
                              setModalState(() => selectedStartAt = DateTime(
                                picked.year, picked.month, picked.day,
                              ));
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            DateFormat('M月d日').format(selectedStartAt),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('schedule-edit-location-field'),
                        controller: locationController,
                        decoration: const InputDecoration(
                          labelText: '地点',
                          hintText: '例如：会议室 A / 线上会议',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('schedule-edit-category-field'),
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: '分类',
                          hintText: '例如：工作、学习、生活',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('schedule-edit-description-field'),
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '描述（可选）',
                          hintText: '补充这条安排的背景或注意事项',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '重复规则',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ScheduleRecurrenceRule.presets.map((option) {
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: option == selectedRecurrence,
                            onSelected: (_) =>
                                setModalState(() => selectedRecurrence = option),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '提醒时间',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ScheduleReminderOption.values.map((option) {
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: option == selectedReminder,
                            onSelected: (_) =>
                                setModalState(() => selectedReminder = option),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '优先级（四象限）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TodoPriority.values.map((option) {
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: option == selectedPriority,
                            onSelected: (_) =>
                                setModalState(() => selectedPriority = option),
                          );
                        }).toList(),
                      ),
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

      final localStart = isAllDay
          ? DateTime(selectedStartAt.year, selectedStartAt.month, selectedStartAt.day)
          : selectedStartAt;
      final localEnd = isAllDay
          ? localStart.add(const Duration(days: 1))
          : (selectedEndAt.isAfter(selectedStartAt)
              ? selectedEndAt
              : selectedStartAt.add(const Duration(hours: 1)));

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
        priority: selectedPriority,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程已更新')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新日程失败：$error')));
      }
    } finally {
      controller.dispose();
      locationController.dispose();
      categoryController.dispose();
      descriptionController.dispose();
    }
  }

  void _moveFocusBackward() {
    setState(() {
      _focusDate = switch (_selectedView) {
        ScheduleViewMode.day => _focusDate.subtract(const Duration(days: 1)),
        ScheduleViewMode.week => _focusDate.subtract(const Duration(days: 7)),
        ScheduleViewMode.month => DateTime(
          _focusDate.year,
          _focusDate.month - 1,
          1,
        ),
        ScheduleViewMode.year => DateTime(_focusDate.year - 1, 1, 1),
      };
    });
  }

  void _moveFocusForward() {
    setState(() {
      _focusDate = switch (_selectedView) {
        ScheduleViewMode.day => _focusDate.add(const Duration(days: 1)),
        ScheduleViewMode.week => _focusDate.add(const Duration(days: 7)),
        ScheduleViewMode.month => DateTime(
          _focusDate.year,
          _focusDate.month + 1,
          1,
        ),
        ScheduleViewMode.year => DateTime(_focusDate.year + 1, 1, 1),
      };
    });
  }

  Future<void> _openCreateScheduleSheet({
    required DateTime startAt,
    required DateTime endAt,
    required bool isAllDay,
  }) async {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedStartAt = startAt.toLocal();
    var selectedEndAt = endAt.toLocal();
    var selectedIsAllDay = isAllDay;
    final defaultPreferences = ref
        .read(userPreferencesProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const UserPreferences(),
        );
    var selectedReminder = defaultPreferences.defaultScheduleReminderOption;
    var selectedRecurrence = ScheduleRecurrenceRule.none;
    var selectedPriority = TodoPriority.notUrgentImportant;

    try {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDateTime({required bool isStart}) async {
                final current =
                    isStart ? selectedStartAt : selectedEndAt;
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  initialDate: current,
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(current),
                );
                if (time == null) return;
                final picked = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                setModalState(() {
                  if (isStart) {
                    selectedStartAt = picked;
                    if (!selectedEndAt.isAfter(selectedStartAt)) {
                      selectedEndAt =
                          selectedStartAt.add(const Duration(hours: 1));
                    }
                  } else {
                    selectedEndAt = picked;
                  }
                });
              }

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
                        '新增日程',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '标题',
                          hintText: '输入日程标题，例如：产品评审会',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        value: selectedIsAllDay,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('全天'),
                        subtitle: const Text('全天日程不显示具体时段'),
                        onChanged: (value) =>
                            setModalState(() => selectedIsAllDay = value),
                      ),
                      const SizedBox(height: 6),
                      if (!selectedIsAllDay) ...<Widget>[
                        OutlinedButton.icon(
                          onPressed: () => pickDateTime(isStart: true),
                          icon: const Icon(Icons.schedule, size: 16),
                          label: Text(
                            '开始：${DateFormat('M月d日 HH:mm').format(selectedStartAt)}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => pickDateTime(isStart: false),
                          icon: const Icon(Icons.schedule_outlined, size: 16),
                          label: Text(
                            '结束：${DateFormat('M月d日 HH:mm').format(selectedEndAt)}',
                          ),
                        ),
                      ] else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                              initialDate: selectedStartAt,
                            );
                            if (picked != null) {
                              setModalState(
                                () => selectedStartAt = DateTime(
                                  picked.year,
                                  picked.month,
                                  picked.day,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            DateFormat('M月d日').format(selectedStartAt),
                          ),
                        ),
                      const SizedBox(height: 12),
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
                      Text(
                        '重复规则',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            ScheduleRecurrenceRule.presets.map((option) {
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: option == selectedRecurrence,
                            onSelected: (_) => setModalState(
                              () => selectedRecurrence = option,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '提醒时间',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            ScheduleReminderOption.values.map((option) {
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: option == selectedReminder,
                            onSelected: (_) => setModalState(
                              () => selectedReminder = option,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '优先级（四象限）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TodoPriority.values.map((option) {
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: option == selectedPriority,
                            onSelected: (_) => setModalState(
                              () => selectedPriority = option,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('新增日程'),
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

      if (confirmed != true || !mounted) return;

      final title = titleController.text.trim();
      if (title.isEmpty) return;

      final localStart = selectedIsAllDay
          ? DateTime(
              selectedStartAt.year,
              selectedStartAt.month,
              selectedStartAt.day,
            )
          : selectedStartAt;
      final localEnd = selectedIsAllDay
          ? localStart.add(const Duration(days: 1))
          : (selectedEndAt.isAfter(selectedStartAt)
              ? selectedEndAt
              : selectedStartAt.add(const Duration(hours: 1)));

      await ref.read(scheduleActionsProvider).createScheduleAt(
        title: title,
        startAt: localStart.toUtc(),
        endAt: localEnd.toUtc(),
        isAllDay: selectedIsAllDay,
        location: locationController.text.trim().isEmpty
            ? null
            : locationController.text.trim(),
        category: categoryController.text.trim().isEmpty
            ? null
            : categoryController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        recurrenceRule: selectedRecurrence.rule,
        reminderMinutesBefore: selectedReminder.minutes,
        priority: selectedPriority,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日程已新增')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增日程失败：$error')));
      }
    } finally {
      titleController.dispose();
      locationController.dispose();
      categoryController.dispose();
      descriptionController.dispose();
    }
  }
}

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({
    required this.summary,
    required this.onTapAll,
    required this.onTapToday,
    required this.onTapUpcoming,
    required this.onTapCompleted,
  });

  final AsyncValue<ScheduleSummary> summary;
  final VoidCallback onTapAll;
  final VoidCallback onTapToday;
  final VoidCallback onTapUpcoming;
  final VoidCallback onTapCompleted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: summary.when(
          data: (value) => Row(
            children: <Widget>[
              Expanded(
                child: _ScheduleMetric(
                  label: '总数',
                  value: value.total.toString(),
                  color: Theme.of(context).colorScheme.primary,
                  onTap: onTapAll,
                ),
              ),
              Expanded(
                child: _ScheduleMetric(
                  label: '今天',
                  value: value.today.toString(),
                  color: const Color(0xFF136F63),
                  onTap: onTapToday,
                ),
              ),
              Expanded(
                child: _ScheduleMetric(
                  label: '即将到来',
                  value: value.upcoming.toString(),
                  color: const Color(0xFFC06C00),
                  onTap: onTapUpcoming,
                ),
              ),
              Expanded(
                child: _ScheduleMetric(
                  label: '已完成',
                  value: value.completed.toString(),
                  color: const Color(0xFF607D8B),
                  onTap: onTapCompleted,
                ),
              ),
            ],
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text('日程统计加载失败：$error'),
        ),
      ),
    );
  }
}

class _ScheduleMetric extends StatelessWidget {
  const _ScheduleMetric({
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

class _ScheduleSearchFilterBar extends StatelessWidget {
  const _ScheduleSearchFilterBar({
    required this.allDayFilterOption,
    required this.selectedCategory,
    required this.categoryOptions,
    required this.onAllDayFilterSelected,
    required this.onCategorySelected,
  });

  final ScheduleAllDayFilterOption allDayFilterOption;
  final String? selectedCategory;
  final List<String> categoryOptions;
  final ValueChanged<ScheduleAllDayFilterOption> onAllDayFilterSelected;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8F6F1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '搜索范围：标题、地点、分类、描述',
              key: const ValueKey('schedule-search-scope-hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ScheduleAllDayFilterOption.values.map((option) {
                return ChoiceChip(
                  key: ValueKey<String>(
                    'schedule-all-day-filter-${option.name}',
                  ),
                  label: Text(option.label),
                  selected: option == allDayFilterOption,
                  onSelected: (_) => onAllDayFilterSelected(option),
                );
              }).toList(),
            ),
            if (categoryOptions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('分类筛选', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  ChoiceChip(
                    key: const ValueKey('schedule-category-filter-all'),
                    label: const Text('全部分类'),
                    selected: selectedCategory == null,
                    onSelected: (_) => onCategorySelected(null),
                  ),
                  ...categoryOptions.map((category) {
                    return ChoiceChip(
                      key: ValueKey<String>(
                        'schedule-category-filter-$category',
                      ),
                      label: Text(category),
                      selected: selectedCategory == category,
                      onSelected: (_) => onCategorySelected(category),
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleListItem extends StatelessWidget {
  const _ScheduleListItem({
    required this.schedule,
    required this.isPending,
    required this.onChanged,
    required this.onOpenDetail,
    required this.onEdit,
  });

  final SchedulesTableData schedule;
  final bool isPending;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final location = schedule.location?.trim();
    final category = schedule.category?.trim();
    final description = schedule.description?.trim();
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
                  value: schedule.status == 'completed',
                  onChanged: isPending ? null : onChanged,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      schedule.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: schedule.status == 'completed'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: ValueKey<String>(
                        'schedule-list-edit-button-${schedule.id}',
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('编辑'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ScheduleTag(
                          label: _buildPrimaryTimeTag(schedule),
                          color: const Color(0xFF136F63),
                        ),
                        if (schedule.isAllDay)
                          const _ScheduleTag(
                            label: '全天',
                            color: Color(0xFF136F63),
                          ),
                        _SchedulePriorityTag(
                          priority: TodoPriority.fromValue(schedule.priority),
                        ),
                        if (location != null && location.isNotEmpty)
                          _ScheduleTag(
                            label: '地点：$location',
                            color: const Color(0xFF8F5A2A),
                          ),
                        if (category != null && category.isNotEmpty)
                          _ScheduleTag(
                            label: '分类：$category',
                            color: const Color(0xFF455A64),
                          ),
                        _ScheduleTag(
                          label: ScheduleReminderOption.fromMinutes(
                            schedule.reminderMinutesBefore,
                          ).label,
                          color: const Color(0xFF607D8B),
                        ),
                        _ScheduleTag(
                          label: ScheduleRecurrenceRule.fromRule(
                            schedule.recurrenceRule,
                          ).label,
                          color: const Color(0xFF9C6F19),
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

  String _buildPrimaryTimeTag(SchedulesTableData schedule) {
    final localStart = schedule.startAt.toLocal();
    final dateLabel = DateFormat('M月d日').format(localStart);
    if (schedule.isAllDay) {
      return '$dateLabel 全天';
    }
    return '$dateLabel ${DateFormat('HH:mm').format(localStart)}';
  }
}

class _ScheduleTag extends StatelessWidget {
  const _ScheduleTag({required this.label, required this.color});

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

class _SchedulePriorityTag extends StatelessWidget {
  const _SchedulePriorityTag({required this.priority});

  final TodoPriority priority;

  Color _color() {
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
    final color = _color();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          priority.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState({required this.filter});

  final ScheduleFilter filter;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.calendar_month_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              filter == ScheduleFilter.all ? '还没有任何日程' : '这个筛选下暂时没有日程',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              '先在上方快速新增一条日程，页面会自动从本地数据库刷新。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleErrorCard extends StatelessWidget {
  const _ScheduleErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: Text(message)),
    );
  }
}
