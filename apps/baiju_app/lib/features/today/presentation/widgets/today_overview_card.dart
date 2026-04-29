import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayOverviewCard extends ConsumerWidget {
  const TodayOverviewCard({
    required this.todoSummary,
    required this.scheduleSummary,
    required this.habitSummary,
    required this.completionRate,
    required this.habitCurrentStreak,
    required this.pendingReminderCount,
    super.key,
  });

  final AsyncValue<TodoSummary> todoSummary;
  final AsyncValue<ScheduleSummary> scheduleSummary;
  final AsyncValue<HabitSummary> habitSummary;
  final AsyncValue<double> completionRate;
  final AsyncValue<int> habitCurrentStreak;
  final AsyncValue<int> pendingReminderCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueCount = ref.watch(dueReminderCountProvider);
    final hasDue = dueCount.maybeWhen(data: (v) => v > 0, orElse: () => false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '总览',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (hasDue) ...<Widget>[
                  const SizedBox(width: 8),
                  _ReminderBadge(
                    count: dueCount.maybeWhen(data: (v) => v, orElse: () => 0),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricBlock(
                    label: '今日日程',
                    value: scheduleSummary.when(
                      data: (value) => value.today.toString(),
                      loading: () => '...',
                      error: (error, stackTrace) => '-',
                    ),
                    color: const Color(0xFF136F63),
                  ),
                ),
                Expanded(
                  child: _MetricBlock(
                    label: '今日待办',
                    value: todoSummary.when(
                      data: (value) => value.today.toString(),
                      loading: () => '...',
                      error: (error, stackTrace) => '-',
                    ),
                    color: const Color(0xFFC06C00),
                  ),
                ),
                Expanded(
                  child: _MetricBlock(
                    label: '习惯已打卡',
                    value: habitSummary.when(
                      data: (value) => value.checkedToday.toString(),
                      loading: () => '...',
                      error: (error, stackTrace) => '-',
                    ),
                    color: const Color(0xFF607D8B),
                  ),
                ),
                Expanded(
                  child: _MetricBlock(
                    label: '待触发提醒',
                    value: pendingReminderCount.when(
                      data: (value) => value.toString(),
                      loading: () => '...',
                      error: (error, stackTrace) => '-',
                    ),
                    color: const Color(0xFF8A5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricBlock(
                    label: '今日完成率',
                    value: completionRate.when(
                      data: (value) => '${(value * 100).round()}%',
                      loading: () => '...',
                      error: (error, stackTrace) => '-',
                    ),
                    color: const Color(0xFF114B45),
                  ),
                ),
                Expanded(
                  child: _MetricBlock(
                    label: '连续打卡天数',
                    value: habitCurrentStreak.when(
                      data: (value) => value.toString(),
                      loading: () => '...',
                      error: (error, stackTrace) => '-',
                    ),
                    color: const Color(0xFFB03A2E),
                  ),
                ),
                const Expanded(child: SizedBox.shrink()),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
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

class _ReminderBadge extends StatelessWidget {
  const _ReminderBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('🔔', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$count 条提醒',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onError,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

