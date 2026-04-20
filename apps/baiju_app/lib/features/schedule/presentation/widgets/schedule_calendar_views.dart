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

  @override
  Widget build(BuildContext context) {
    final content = switch (selectedView) {
      ScheduleViewMode.day => DayScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        pendingScheduleIds: pendingScheduleIds,
        onToggleSchedule: onToggleSchedule,
        onOpenScheduleDetail: onOpenScheduleDetail,
      ),
      ScheduleViewMode.week => WeekScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        onOpenScheduleDetail: onOpenScheduleDetail,
      ),
      ScheduleViewMode.month => MonthScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        onOpenScheduleDetail: onOpenScheduleDetail,
        onSelectDate: onSelectDate,
      ),
      ScheduleViewMode.year => YearScheduleView(
        focusDate: focusDate,
        schedules: schedules,
        onSelectMonth: onSelectMonth,
      ),
    };

    return Card(
      child: Padding(padding: const EdgeInsets.all(18), child: content),
    );
  }
}

class DayScheduleView extends StatelessWidget {
  const DayScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.pendingScheduleIds,
    required this.onToggleSchedule,
    required this.onOpenScheduleDetail,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final Set<String> pendingScheduleIds;
  final Future<void> Function(SchedulesTableData, bool) onToggleSchedule;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;

  @override
  Widget build(BuildContext context) {
    final daySchedules =
        schedules
            .where(
              (schedule) => sameDate(schedule.startAt.toLocal(), focusDate),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    if (daySchedules.isEmpty) {
      return const EmptyScheduleViewState(
        title: '这一天还没有日程',
        description: '可以先新增一条日程，日视图会按小时展示。',
      );
    }

    final allDaySchedules = daySchedules
        .where((schedule) => schedule.isAllDay)
        .toList();
    final timedSchedules = daySchedules
        .where((schedule) => !schedule.isAllDay)
        .toList();

    final grouped = <int, List<SchedulesTableData>>{};
    for (final schedule in timedSchedules) {
      grouped
          .putIfAbsent(
            schedule.startAt.toLocal().hour,
            () => <SchedulesTableData>[],
          )
          .add(schedule);
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
                  (schedule) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AllDaySchedulePill(
                      schedule: schedule,
                      onOpenScheduleDetail: onOpenScheduleDetail,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (timedSchedules.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              '今天暂无分时段日程',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          ...List<Widget>.generate(17, (index) {
            final hour = index + 6;
            final items = grouped[hour] ?? const <SchedulesTableData>[];

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x11000000))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 58,
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const SizedBox(height: 10)
                        : Column(
                            children: items
                                .map(
                                  (schedule) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: DayScheduleBlock(
                                      schedule: schedule,
                                      isPending: pendingScheduleIds.contains(
                                        schedule.id,
                                      ),
                                      onChanged: (value) => onToggleSchedule(
                                        schedule,
                                        value ?? false,
                                      ),
                                      onOpenDetail: () =>
                                          onOpenScheduleDetail(schedule),
                                    ),
                                  ),
                                )
                                .toList(),
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

class WeekScheduleView extends StatelessWidget {
  const WeekScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.onOpenScheduleDetail,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;

  @override
  Widget build(BuildContext context) {
    final weekStart = startOfWeek(focusDate);

    return Column(
      children: List<Widget>.generate(7, (index) {
        final day = weekStart.add(Duration(days: index));
        final daySchedules =
            schedules
                .where((schedule) => sameDate(schedule.startAt.toLocal(), day))
                .toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final allDaySchedules = daySchedules
            .where((schedule) => schedule.isAllDay)
            .toList();
        final timedSchedules = daySchedules
            .where((schedule) => !schedule.isAllDay)
            .toList();

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
              Text(
                '${weekdayShort(day.weekday)} ${DateFormat('M月d日').format(day)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (daySchedules.isEmpty)
                const Text('当天暂无日程')
              else ...<Widget>[
                if (allDaySchedules.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allDaySchedules
                        .map(
                          (schedule) => InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => onOpenScheduleDetail(schedule),
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
                                '全天 ${schedule.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
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
                  const SizedBox(height: 8),
                ],
                ...timedSchedules.map(
                  (schedule) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onOpenScheduleDetail(schedule),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          '${DateFormat('HH:mm').format(schedule.startAt.toLocal())} ${schedule.title}',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class MonthScheduleView extends StatelessWidget {
  const MonthScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.onOpenScheduleDetail,
    required this.onSelectDate,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final ValueChanged<SchedulesTableData> onOpenScheduleDetail;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(focusDate.year, focusDate.month, 1);
    final gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday - 1),
    );

    return Column(
      children: <Widget>[
        Row(
          children: const <Widget>[
            MonthWeekday(label: '一'),
            MonthWeekday(label: '二'),
            MonthWeekday(label: '三'),
            MonthWeekday(label: '四'),
            MonthWeekday(label: '五'),
            MonthWeekday(label: '六'),
            MonthWeekday(label: '日'),
          ],
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(6, (weekIndex) {
          return Row(
            children: List<Widget>.generate(7, (dayIndex) {
              final day = gridStart.add(
                Duration(days: weekIndex * 7 + dayIndex),
              );
              final daySchedules =
                  schedules
                      .where(
                        (schedule) => sameDate(schedule.startAt.toLocal(), day),
                      )
                      .toList()
                    ..sort((a, b) => a.startAt.compareTo(b.startAt));
              final allDaySchedules = daySchedules
                  .where((schedule) => schedule.isAllDay)
                  .toList();
              final previewSchedules = <SchedulesTableData>[
                ...allDaySchedules,
                ...daySchedules.where((schedule) => !schedule.isAllDay),
              ].take(1).toList();
              final isCurrentMonth = day.month == focusDate.month;

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelectDate(day),
                  child: Container(
                    height: 100,
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrentMonth
                          ? const Color(0xFFF8F6F1)
                          : const Color(0xFFF1EFE9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isCurrentMonth
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (daySchedules.isNotEmpty)
                          Text(
                            '${daySchedules.length} 项',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF136F63)),
                          ),
                        if (allDaySchedules.isNotEmpty)
                          Text(
                            '全天 ${allDaySchedules.length}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: const Color(0xFF7A4B00)),
                          ),
                        const SizedBox(height: 4),
                        ...previewSchedules
                            .map(
                              (schedule) => InkWell(
                                onTap: () => onOpenScheduleDetail(schedule),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    schedule.isAllDay
                                        ? '全天 ${schedule.title}'
                                        : '${DateFormat('HH:mm').format(schedule.startAt.toLocal())} ${schedule.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF114B45),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

class YearScheduleView extends StatelessWidget {
  const YearScheduleView({
    required this.focusDate,
    required this.schedules,
    required this.onSelectMonth,
    super.key,
  });

  final DateTime focusDate;
  final List<SchedulesTableData> schedules;
  final ValueChanged<DateTime> onSelectMonth;

  @override
  Widget build(BuildContext context) {
    final yearSchedules = schedules
        .where((schedule) => schedule.startAt.toLocal().year == focusDate.year)
        .toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List<Widget>.generate(12, (index) {
        final month = index + 1;
        final monthSchedules =
            yearSchedules
                .where((schedule) => schedule.startAt.toLocal().month == month)
                .toList()
              ..sort((a, b) => a.startAt.compareTo(b.startAt));
        final allDayCount =
            monthSchedules.where((schedule) => schedule.isAllDay).length;

        return SizedBox(
          width: 160,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelectMonth(DateTime(focusDate.year, month, 1)),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F6F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$month月',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('共 ${monthSchedules.length} 项日程'),
                  if (allDayCount > 0)
                    Text(
                      '全天 $allDayCount 项',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: const Color(0xFF7A4B00)),
                    ),
                  const SizedBox(height: 6),
                  if (monthSchedules.isNotEmpty)
                    Text(
                      '最近：${monthSchedules.first.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    const Text('本月暂无日程'),
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
