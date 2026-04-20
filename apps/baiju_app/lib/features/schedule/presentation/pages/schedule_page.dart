import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/schedule/presentation/widgets/schedule_calendar_views.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
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
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Set<String> _pendingScheduleIds = <String>{};

  QuickScheduleDay _selectedDay = QuickScheduleDay.today;
  QuickScheduleSlot _selectedSlot = QuickScheduleSlot.morning;
  ScheduleDurationOption _selectedDuration = ScheduleDurationOption.oneHour;
  ScheduleReminderOption _selectedReminder = ScheduleReminderOption.fifteen;
  ScheduleRecurrenceRule _selectedRecurrence = ScheduleRecurrenceRule.none;
  ScheduleViewMode _selectedView = ScheduleViewMode.day;
  ScheduleSortOption _sortOption = ScheduleSortOption.startAsc;
  ScheduleAllDayFilterOption _allDayFilterOption =
      ScheduleAllDayFilterOption.all;
  DateTime _focusDate = DateTime.now();
  String? _selectedCategoryFilter;
  bool _isAllDay = false;
  bool _isCreating = false;
  bool _defaultReminderHydrated = false;
  String? _defaultReminderWorkspaceId;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(currentUserWorkspaceProvider);
    final preferences = ref.watch(userPreferencesProvider);
    final summary = ref.watch(scheduleSummaryProvider);
    final schedules = ref.watch(scheduleListProvider);
    final allSchedules = ref.watch(allScheduleListProvider);
    final selectedFilter = ref.watch(selectedScheduleFilterProvider);
    final theme = Theme.of(context);

    preferences.whenData((value) {
      final shouldHydrate =
          !_defaultReminderHydrated ||
          _defaultReminderWorkspaceId != workspace.workspaceId;
      if (!shouldHydrate) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedReminder = value.defaultScheduleReminderOption;
          _defaultReminderHydrated = true;
          _defaultReminderWorkspaceId = workspace.workspaceId;
        });
      });
    });

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
          _ScheduleSummaryCard(summary: summary),
          const SizedBox(height: 16),
          _ScheduleWorkbenchCard(
            summary: summary,
            selectedView: _selectedView,
            selectedFilter: selectedFilter,
            focusDate: _focusDate,
            onOpenToday: () => context.push('/today'),
            onOpenTimeline: () => context.push('/timeline'),
          ),
          const SizedBox(height: 16),
          _QuickCreateScheduleCard(
            controller: _titleController,
            locationController: _locationController,
            categoryController: _categoryController,
            descriptionController: _descriptionController,
            isCreating: _isCreating,
            isAllDay: _isAllDay,
            selectedDay: _selectedDay,
            selectedSlot: _selectedSlot,
            selectedDuration: _selectedDuration,
            selectedReminder: _selectedReminder,
            selectedRecurrence: _selectedRecurrence,
            onAllDayChanged: (value) => setState(() => _isAllDay = value),
            onDayChanged: (value) => setState(() => _selectedDay = value),
            onSlotChanged: (value) => setState(() => _selectedSlot = value),
            onDurationChanged: (value) =>
                setState(() => _selectedDuration = value),
            onReminderChanged: (value) =>
                setState(() => _selectedReminder = value),
            onRecurrenceChanged: (value) =>
                setState(() => _selectedRecurrence = value),
            onSubmit: _createSchedule,
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

  Future<void> _createSchedule() async {
    final workspace = ref.read(currentUserWorkspaceProvider);
    final title = _titleController.text.trim();
    if (title.isEmpty || _isCreating) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isCreating = true);

    try {
      await ref.read(scheduleActionsProvider).createSchedule(
        title: title,
        day: _selectedDay,
        slot: _selectedSlot,
        duration: _selectedDuration,
        reminder: _selectedReminder,
        recurrence: _selectedRecurrence,
        description: _descriptionController.text,
        location: _locationController.text,
        category: _categoryController.text,
        isAllDay: _isAllDay,
      );

      _titleController.clear();
      _locationController.clear();
      _categoryController.clear();
      _descriptionController.clear();
      final defaultPreferences = ref
          .read(userPreferencesProvider)
          .maybeWhen(
            data: (value) => value,
            orElse: () => const UserPreferences(),
          );
      if (mounted) {
        setState(() {
          _selectedDay = QuickScheduleDay.today;
          _selectedSlot = QuickScheduleSlot.morning;
          _selectedDuration = ScheduleDurationOption.oneHour;
          _selectedReminder = defaultPreferences.defaultScheduleReminderOption;
          _selectedRecurrence = ScheduleRecurrenceRule.none;
          _isAllDay = false;
          _defaultReminderHydrated = true;
          _defaultReminderWorkspaceId = workspace.workspaceId;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增日程失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
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
        isScrollControlled: true,
        showDragHandle: true,
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
                        key: const ValueKey('schedule-edit-is-all-day-switch'),
                        value: isAllDay,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('全天'),
                        subtitle: const Text('全天日程不显示具体时段'),
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
                      if (!isAllDay) ...<Widget>[
                        Text(
                          '时长',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              ScheduleDurationOption.values.map((option) {
                            return ChoiceChip(
                              label: Text(option.label),
                              selected: option == selectedDuration,
                              onSelected: (_) => setModalState(
                                () => selectedDuration = option,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ] else
                        Text(
                          '全天默认占用所选日期 00:00 - 次日 00:00。',
                          style: Theme.of(context).textTheme.bodyMedium,
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

  ScheduleDurationOption _durationFromSchedule(SchedulesTableData schedule) {
    final minutes = schedule.endAt.difference(schedule.startAt).inMinutes;
    return ScheduleDurationOption.values.firstWhere(
      (option) => option.minutes == minutes,
      orElse: () => ScheduleDurationOption.oneHour,
    );
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
}

class _ScheduleSummaryCard extends StatelessWidget {
  const _ScheduleSummaryCard({required this.summary});

  final AsyncValue<ScheduleSummary> summary;

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
                ),
              ),
              Expanded(
                child: _ScheduleMetric(
                  label: '今天',
                  value: value.today.toString(),
                  color: const Color(0xFF136F63),
                ),
              ),
              Expanded(
                child: _ScheduleMetric(
                  label: '即将到来',
                  value: value.upcoming.toString(),
                  color: const Color(0xFFC06C00),
                ),
              ),
              Expanded(
                child: _ScheduleMetric(
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
          error: (error, stackTrace) => Text('日程统计加载失败：$error'),
        ),
      ),
    );
  }
}

class _ScheduleWorkbenchCard extends StatelessWidget {
  const _ScheduleWorkbenchCard({
    required this.summary,
    required this.selectedView,
    required this.selectedFilter,
    required this.focusDate,
    required this.onOpenToday,
    required this.onOpenTimeline,
  });

  final AsyncValue<ScheduleSummary> summary;
  final ScheduleViewMode selectedView;
  final ScheduleFilter selectedFilter;
  final DateTime focusDate;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenTimeline;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F0E5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '日程工作台',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '把当前视图、日期焦点和时间线入口直接提到主页，方便快速切换。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpenToday,
                  icon: const Icon(Icons.today_outlined),
                  label: const Text('今日页'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            summary.when(
              data: (value) => Row(
                children: <Widget>[
                  Expanded(
                    child: _ScheduleMetric(
                      label: '今天',
                      value: '${value.today}',
                      color: const Color(0xFF136F63),
                    ),
                  ),
                  Expanded(
                    child: _ScheduleMetric(
                      label: '即将到来',
                      value: '${value.upcoming}',
                      color: const Color(0xFFC06C00),
                    ),
                  ),
                  Expanded(
                    child: _ScheduleMetric(
                      label: '已完成',
                      value: '${value.completed}',
                      color: const Color(0xFF607D8B),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('统计加载失败：$error'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('视图：${selectedView.label}')),
                Chip(label: Text('筛选：${selectedFilter.label}')),
                Chip(label: Text('焦点：${DateFormat('M月d日').format(focusDate)}')),
                ActionChip(label: const Text('时间线'), onPressed: onOpenTimeline),
              ],
            ),
          ],
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

class _QuickCreateScheduleCard extends StatelessWidget {
  const _QuickCreateScheduleCard({
    required this.controller,
    required this.locationController,
    required this.categoryController,
    required this.descriptionController,
    required this.isCreating,
    required this.isAllDay,
    required this.selectedDay,
    required this.selectedSlot,
    required this.selectedDuration,
    required this.selectedReminder,
    required this.selectedRecurrence,
    required this.onAllDayChanged,
    required this.onDayChanged,
    required this.onSlotChanged,
    required this.onDurationChanged,
    required this.onReminderChanged,
    required this.onRecurrenceChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final TextEditingController locationController;
  final TextEditingController categoryController;
  final TextEditingController descriptionController;
  final bool isCreating;
  final bool isAllDay;
  final QuickScheduleDay selectedDay;
  final QuickScheduleSlot selectedSlot;
  final ScheduleDurationOption selectedDuration;
  final ScheduleReminderOption selectedReminder;
  final ScheduleRecurrenceRule selectedRecurrence;
  final ValueChanged<bool> onAllDayChanged;
  final ValueChanged<QuickScheduleDay> onDayChanged;
  final ValueChanged<QuickScheduleSlot> onSlotChanged;
  final ValueChanged<ScheduleDurationOption> onDurationChanged;
  final ValueChanged<ScheduleReminderOption> onReminderChanged;
  final ValueChanged<ScheduleRecurrenceRule> onRecurrenceChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('快速新增日程', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !isCreating,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                hintText: '输入日程标题，例如：产品评审会',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              key: const ValueKey('schedule-quick-is-all-day-switch'),
              value: isAllDay,
              contentPadding: EdgeInsets.zero,
              title: const Text('全天'),
              subtitle: const Text('全天安排不需要具体时段'),
              onChanged: isCreating ? null : onAllDayChanged,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('schedule-quick-location-field'),
              controller: locationController,
              enabled: !isCreating,
              decoration: const InputDecoration(
                labelText: '地点',
                hintText: '例如：会议室 A / 线上会议',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('schedule-quick-category-field'),
              controller: categoryController,
              enabled: !isCreating,
              decoration: const InputDecoration(
                labelText: '分类',
                hintText: '例如：工作、学习、生活',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('schedule-quick-description-field'),
              controller: descriptionController,
              enabled: !isCreating,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                hintText: '补充背景、目标或会议上下文',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuickScheduleDay.values.map((day) {
                return ChoiceChip(
                  label: Text(day.label),
                  selected: day == selectedDay,
                  onSelected: isCreating ? null : (_) => onDayChanged(day),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (!isAllDay) ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: QuickScheduleSlot.values.map((slot) {
                  return ChoiceChip(
                    label: Text(slot.label),
                    selected: slot == selectedSlot,
                    onSelected: isCreating ? null : (_) => onSlotChanged(slot),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ScheduleDurationOption.values.map((option) {
                  return ChoiceChip(
                    label: Text(option.label),
                    selected: option == selectedDuration,
                    onSelected: isCreating
                        ? null
                        : (_) => onDurationChanged(option),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ] else
              Text(
                '全天将默认覆盖所选日期 00:00 - 次日 00:00。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Text('重复规则', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ScheduleRecurrenceRule.presets.map((option) {
                return ChoiceChip(
                  label: Text(option.label),
                  selected: option == selectedRecurrence,
                  onSelected: isCreating
                      ? null
                      : (_) => onRecurrenceChanged(option),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text('提醒时间', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ScheduleReminderOption.values.map((option) {
                return ChoiceChip(
                  label: Text(option.label),
                  selected: option == selectedReminder,
                  onSelected: isCreating
                      ? null
                      : (_) => onReminderChanged(option),
                );
              }).toList(),
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
                label: Text(isCreating ? '保存中' : '新增日程'),
              ),
            ),
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
