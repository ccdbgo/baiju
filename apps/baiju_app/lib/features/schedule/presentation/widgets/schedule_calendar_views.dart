import 'package:baiju_app/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ScheduleViewMode {
  day('日视图', Icons.view_day_outlined),
  week('周视图', Icons.view_week_outlined),
  month('月视图', Icons.calendar_view_month_outlined),
  year('年视图', Icons.calendar_today_outlined);

  const ScheduleViewMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ViewHeader extends StatelessWidget {
  const ViewHeader({
    required this.selectedView,
    required this.focusDate,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
    super.key,
  });

  final ScheduleViewMode selectedView;
  final DateTime focusDate;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = switch (selectedView) {
      ScheduleViewMode.day => DateFormat('M月d日').format(focusDate),
      ScheduleViewMode.week =>
        '${DateFormat('M月d日').format(startOfWeek(focusDate))} - ${DateFormat('M月d日').format(startOfWeek(focusDate).add(const Duration(days: 6)))}',
      ScheduleViewMode.month => DateFormat('yyyy年M月').format(focusDate),
      ScheduleViewMode.year => DateFormat('yyyy年').format(focusDate),
    };

    return Row(
      children: <Widget>[
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Text(
            label,
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

class ScheduleViewCard extends StatelessWidget {
  const ScheduleViewCard({
    required this.selectedView,
    required this.focusDate,
    required this.schedules,
    required this.pendingScheduleIds,
    required this.onToggleSchedule,
    required this.onOpenScheduleDetail,
    required this.onSelectDate,
    required this.onSelectMonth,
    required this.onInlineCreate,
    super.key,
  });

  final ScheduleViewMode selectedView;
  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final Set<String> pendingScheduleIds;
  final Future<void> Function(SchedulesTableData, bool) onToggleSchedule;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DateTime> onSelectMonth;
  final Future<void> Function(String title, DateTime startAt, DateTime endAt, bool isAllDay)
      onInlineCreate;

  @override
  Widget build(BuildContext context) {
    final content = switch (selectedView) {
      ScheduleViewMode.day => DayScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        pendingScheduleIds: pendingScheduleIds,
        onToggleSchedule: onToggleSchedule,
        onOpenScheduleDetail: onOpenScheduleDetail,
        onInlineCreate: onInlineCreate,
      ),
      ScheduleViewMode.week => WeekScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        onOpenScheduleDetail: onOpenScheduleDetail,
        onInlineCreate: onInlineCreate,
      ),
      ScheduleViewMode.month => MonthScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        onOpenScheduleDetail: onOpenScheduleDetail,
        onSelectDate: onSelectDate,
        onInlineCreate: onInlineCreate,
      ),
      ScheduleViewMode.year => YearScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        onSelectMonth: onSelectMonth,
        onInlineCreate: onInlineCreate,
      ),
    };

    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: content),
    );
  }
}

class DayScheduleView extends StatefulWidget {
  const DayScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.pendingScheduleIds,
    required this.onToggleSchedule,
    required this.onOpenScheduleDetail,
    required this.onInlineCreate,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final Set<String> pendingScheduleIds;
  final Future<void> Function(SchedulesTableData, bool) onToggleSchedule;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;
  final Future<void> Function(String title, DateTime startAt, DateTime endAt, bool isAllDay)
      onInlineCreate;

  @override
  State<DayScheduleView> createState() => _DayScheduleViewState();
}

class _DayScheduleViewState extends State<DayScheduleView> {
  int? _editingHour; // null = no inline editor open

  @override
  Widget build(BuildContext context) {
    final daySchedules =
        widget.schedules
            .where(
              (s) => sameDate(s.startAt.toLocal(), widget.focusDate),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final allDaySchedules =
        daySchedules.where((s) => s.isAllDay).toList();
    final timedSchedules =
        daySchedules.where((s) => !s.isAllDay).toList();

    final grouped = <int, List<SchedulesTableData>>{};
    for (final s in timedSchedules) {
      grouped
          .putIfAbsent(s.startAt.toLocal().hour, () => <SchedulesTableData>[])
          .add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (allDaySchedules.isNotEmpty) ...<Widget>[
          Container(
            key: const ValueKey('day-view-all-day-section'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.wb_sunny_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '全天安排',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...allDaySchedules.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AllDaySchedulePill(
                      schedule: s,
                      onOpenScheduleDetail: widget.onOpenScheduleDetail,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        // 24-hour timeline
        ...List<Widget>.generate(24, (index) {
          final hour = index;
          final items = grouped[hour] ?? const <SchedulesTableData>[];
          final isEditing = _editingHour == hour;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x11000000))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // 左侧时间轴
                SizedBox(
                  width: 52,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                // 右侧内容区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (items.isNotEmpty)
                        ...items.map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: DayScheduleBlock(
                              schedule: s,
                              isPending: widget.pendingScheduleIds
                                  .contains(s.id),
                              onChanged: (v) => widget.onToggleSchedule(
                                s,
                                v ?? false,
                              ),
                              onOpenDetail: () =>
                                  widget.onOpenScheduleDetail(s),
                            ),
                          ),
                        ),
                      if (isEditing)
                        _InlineEditor(
                          hint: '${hour.toString().padLeft(2, '0')}:00 的日程',
                          onSubmit: (title) async {
                            final d = widget.focusDate;
                            final start = DateTime(
                              d.year, d.month, d.day, hour,
                            ).toUtc();
                            final end = start.add(const Duration(hours: 1));
                            await widget.onInlineCreate(title, start, end, false);
                            if (mounted) setState(() => _editingHour = null);
                          },
                          onCancel: () =>
                              setState(() => _editingHour = null),
                        )
                      else
                        // 点击空白区域打开编辑器
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              setState(() => _editingHour = hour),
                          child: Container(
                            height: 24,
                            alignment: Alignment.centerLeft,
                            child: items.isEmpty
                                ? Text(
                                    '+ 点击添加',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.4),
                                        ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class DayScheduleBlock extends StatelessWidget {
  const DayScheduleBlock({
    required this.schedule,
    required this.isPending,
    required this.onChanged,
    required this.onOpenDetail,
    super.key,
  });

  final SchedulesTableData schedule;
  final bool isPending;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final start = DateFormat('HH:mm').format(schedule.startAt.toLocal());
    final end = DateFormat('HH:mm').format(schedule.endAt.toLocal());

    return Material(
      color: const Color(0xFFE8F2EF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: schedule.status == 'completed',
                onChanged: isPending ? null : onChanged,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      schedule.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$start - $end'),
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

class _AllDaySchedulePill extends StatelessWidget {
  const _AllDaySchedulePill({
    required this.schedule,
    required this.onOpenScheduleDetail,
  });

  final SchedulesTableData schedule;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onOpenScheduleDetail(schedule),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE0B2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          schedule.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF7A4B00),
          ),
        ),
      ),
    );
  }
}

class WeekScheduleView extends StatefulWidget {
  const WeekScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.onOpenScheduleDetail,
    required this.onInlineCreate,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;
  final Future<void> Function(String title, DateTime startAt, DateTime endAt, bool isAllDay)
      onInlineCreate;

  @override
  State<WeekScheduleView> createState() => _WeekScheduleViewState();
}

class _WeekScheduleViewState extends State<WeekScheduleView> {
  DateTime? _editingDay;

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(widget.focusDate);

    return Column(
      children: List<Widget>.generate(7, (index) {
        final day = weekStart.add(Duration(days: index));
        final daySchedules =
            widget.schedules
                .where((s) => sameDate(s.startAt.toLocal(), day))
                .toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final allDaySchedules = daySchedules.where((s) => s.isAllDay).toList();
        final timedSchedules =
            daySchedules.where((s) => !s.isAllDay).toList();
        final isEditing =
            _editingDay != null && sameDate(_editingDay!, day);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${weekdayShort(day.weekday)} ${DateFormat('M月d日').format(day)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (!isEditing)
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: '添加计划',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _editingDay = day),
                    ),
                ],
              ),
              if (allDaySchedules.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: allDaySchedules
                      .map(
                        (s) => InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => widget.onOpenScheduleDetail(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE0B2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '全天 ${s.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF7A4B00),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (timedSchedules.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                ...timedSchedules.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => widget.onOpenScheduleDetail(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          '${DateFormat('HH:mm').format(s.startAt.toLocal())} ${s.title}',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (daySchedules.isEmpty && !isEditing)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '当天暂无日程，点击 + 添加',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.5),
                    ),
                  ),
                ),
              if (isEditing) ...<Widget>[
                const SizedBox(height: 8),
                _InlineEditor(
                  hint: '${DateFormat('M月d日').format(day)} 的计划',
                  onSubmit: (title) async {
                    final start = DateTime(
                      day.year, day.month, day.day,
                    ).toUtc();
                    final end = DateTime(
                      day.year, day.month, day.day + 1,
                    ).toUtc();
                    await widget.onInlineCreate(title, start, end, true);
                    if (mounted) setState(() => _editingDay = null);
                  },
                  onCancel: () => setState(() => _editingDay = null),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class MonthScheduleView extends StatefulWidget {
  const MonthScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.onOpenScheduleDetail,
    required this.onSelectDate,
    required this.onInlineCreate,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;
  final ValueChanged<DateTime> onSelectDate;
  final Future<void> Function(String title, DateTime startAt, DateTime endAt, bool isAllDay)
      onInlineCreate;

  @override
  State<MonthScheduleView> createState() => _MonthScheduleViewState();
}

class _MonthScheduleViewState extends State<MonthScheduleView> {
  int? _editingWeek; // week index 0-5

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(widget.focusDate.year, widget.focusDate.month, 1);
    final gridStart = monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final theme = Theme.of(context);

    return Column(
      children: List<Widget>.generate(6, (weekIndex) {
        final weekStart = gridStart.add(Duration(days: weekIndex * 7));
        final weekEnd = weekStart.add(const Duration(days: 7));
        final weekSchedules = widget.schedules
            .where((s) {
              final d = s.startAt.toLocal();
              return !d.isBefore(weekStart) && d.isBefore(weekEnd);
            })
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final isEditing = _editingWeek == weekIndex;

        // 跳过完全不属于本月的周
        final hasCurrentMonth = List.generate(7, (i) => weekStart.add(Duration(days: i)))
            .any((d) => d.month == widget.focusDate.month);
        if (!hasCurrentMonth) return const SizedBox.shrink();

        final weekLabel =
            '${DateFormat('M/d').format(weekStart)}–${DateFormat('M/d').format(weekEnd.subtract(const Duration(days: 1)))}';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isEditing ? null : () => setState(() => _editingWeek = weekIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 左侧纵轴：周标签
                  SizedBox(
                    width: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '第${weekIndex + 1}周',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          weekLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 右侧内容区
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (isEditing)
                          _InlineEditor(
                            hint: '添加本周计划',
                            compact: true,
                            onSubmit: (title) async {
                              final start = weekStart.toUtc();
                              final end = weekEnd.toUtc();
                              await widget.onInlineCreate(title, start, end, true);
                              if (mounted) setState(() => _editingWeek = null);
                            },
                            onCancel: () => setState(() => _editingWeek = null),
                          )
                        else if (weekSchedules.isEmpty)
                          Text(
                            '+ 点击添加计划',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline.withOpacity(0.5),
                            ),
                          )
                        else
                          ...weekSchedules.take(3).map(
                            (s) => InkWell(
                              onTap: () => widget.onOpenScheduleDetail(s),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  s.isAllDay
                                      ? '全天 ${s.title}'
                                      : '${DateFormat('E HH:mm', 'zh').format(s.startAt.toLocal())} ${s.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF114B45),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!isEditing && weekSchedules.length > 3)
                          Text(
                            '还有 ${weekSchedules.length - 3} 项...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class YearScheduleView extends StatefulWidget {
  const YearScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.onSelectMonth,
    required this.onInlineCreate,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final ValueChanged<DateTime> onSelectMonth;
  final Future<void> Function(String title, DateTime startAt, DateTime endAt, bool isAllDay)
      onInlineCreate;

  @override
  State<YearScheduleView> createState() => _YearScheduleViewState();
}

class _YearScheduleViewState extends State<YearScheduleView> {
  int? _editingMonth;

  @override
  Widget build(BuildContext context) {
    final yearSchedules = widget.schedules
        .where((s) => s.startAt.toLocal().year == widget.focusDate.year)
        .toList();
    final theme = Theme.of(context);

    return Column(
      children: List<Widget>.generate(12, (index) {
        final month = index + 1;
        final monthSchedules = yearSchedules
            .where((s) => s.startAt.toLocal().month == month)
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final isEditing = _editingMonth == month;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isEditing ? null : () => setState(() => _editingMonth = month),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 左侧纵轴：月份标签
                  SizedBox(
                    width: 48,
                    child: InkWell(
                      onTap: () => widget.onSelectMonth(
                        DateTime(widget.focusDate.year, month, 1),
                      ),
                      child: Text(
                        '$month月',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 右侧内容区
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (isEditing)
                          _InlineEditor(
                            hint: '$month月的目标计划',
                            compact: true,
                            onSubmit: (title) async {
                              final start = DateTime(
                                widget.focusDate.year, month, 1,
                              ).toUtc();
                              final end = DateTime(
                                widget.focusDate.year, month + 1, 1,
                              ).toUtc();
                              await widget.onInlineCreate(title, start, end, true);
                              if (mounted) setState(() => _editingMonth = null);
                            },
                            onCancel: () => setState(() => _editingMonth = null),
                          )
                        else if (monthSchedules.isEmpty)
                          Text(
                            '+ 点击添加目标',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline.withOpacity(0.5),
                            ),
                          )
                        else
                          ...monthSchedules.take(3).map(
                            (s) => InkWell(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF114B45),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (!isEditing && monthSchedules.length > 3)
                          Text(
                            '还有 ${monthSchedules.length - 3} 项...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class MonthWeekday extends StatelessWidget {
  const MonthWeekday({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class EmptyScheduleViewState extends StatelessWidget {
  const EmptyScheduleViewState({
    required this.title,
    required this.description,
    super.key,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(
          Icons.event_busy_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center),
      ],
    );
  }
}

bool sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

DateTime startOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  return local.subtract(Duration(days: local.weekday - 1));
}

String weekdayShort(int weekday) {
  const labels = <int, String>{
    DateTime.monday: '周一',
    DateTime.tuesday: '周二',
    DateTime.wednesday: '周三',
    DateTime.thursday: '周四',
    DateTime.friday: '周五',
    DateTime.saturday: '周六',
    DateTime.sunday: '周日',
  };
  return labels[weekday] ?? '';
}

/// Lightweight inline text editor used in calendar views to quickly create
/// a schedule entry without navigating away.
class _InlineEditor extends StatefulWidget {
  const _InlineEditor({
    required this.hint,
    required this.onSubmit,
    required this.onCancel,
    this.compact = false,
  });

  final String hint;
  final Future<void> Function(String title) onSubmit;
  final VoidCallback onCancel;
  final bool compact;

  @override
  State<_InlineEditor> createState() => _InlineEditorState();
}

class _InlineEditorState extends State<_InlineEditor> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(title);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            style: widget.compact
                ? theme.textTheme.bodySmall
                : theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withOpacity(0.5),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 4),
        if (_submitting)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...<Widget>[
          IconButton(
            icon: const Icon(Icons.check, size: 18),
            tooltip: '确认',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _submit,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: '取消',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onCancel,
          ),
        ],
      ],
    );
  }
}
