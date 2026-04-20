import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_export_formatter.dart';
import 'package:baiju_app/features/timeline/presentation/providers/timeline_providers.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum TimelineSortOption {
  newestFirst('最新优先'),
  oldestFirst('最早优先');

  const TimelineSortOption(this.label);

  final String label;
}

class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  final TextEditingController _searchController = TextEditingController();
  TimelineSortOption _sortOption = TimelineSortOption.newestFirst;

  String get _searchQuery => _searchController.text.trim();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedFilter = ref.watch(selectedTimelineFilterProvider);
    final selectedRange = ref.watch(selectedTimelineRangeProvider);
    final events = ref.watch(timelineEventsProvider);
    final summary = ref.watch(timelineSummaryProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('时间线', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '这里集中回看最近发生的真实事件，支持关键词搜索、类型过滤、时间范围和顺序切换。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _TimelineSummaryCard(summary: summary),
          const SizedBox(height: 16),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索时间线',
            hintText: '按标题、摘要、动作关键词筛选事件',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SelectionChipBar<TimelineSortOption>(
            values: TimelineSortOption.values,
            selected: _sortOption,
            labelBuilder: (value) => value.label,
            onSelected: (value) => setState(() => _sortOption = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TimelineFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(filter.label),
                selected: filter == selectedFilter,
                onSelected: (_) => ref
                    .read(selectedTimelineFilterProvider.notifier)
                    .select(filter),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TimelineRangePreset.values.map((preset) {
              return ChoiceChip(
                label: Text(preset.label),
                selected: preset == selectedRange.preset,
                onSelected: (_) async {
                  if (preset == TimelineRangePreset.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                      initialDateRange: selectedRange.range,
                    );
                    if (picked != null) {
                      ref
                          .read(selectedTimelineRangeProvider.notifier)
                          .selectCustomRange(picked);
                    }
                    return;
                  }
                  ref
                      .read(selectedTimelineRangeProvider.notifier)
                      .selectPreset(preset);
                },
              );
            }).toList(),
          ),
          if (selectedRange.preset == TimelineRangePreset.custom &&
              selectedRange.range != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '范围：${DateFormat('M月d日').format(selectedRange.range!.start)} - ${DateFormat('M月d日').format(selectedRange.range!.end)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          events.when(
            data: (items) {
              final visibleItems = _filterAndSortItems(items);
              if (visibleItems.isEmpty) {
                return _EmptyTimelineState(searchQuery: _searchQuery);
              }

              final grouped = <DateTime, List<TimelineEventsTableData>>{};
              for (final event in visibleItems) {
                final local = event.occurredAt.toLocal();
                final day = DateTime(local.year, local.month, local.day);
                grouped
                    .putIfAbsent(day, () => <TimelineEventsTableData>[])
                    .add(event);
              }

              final days = grouped.keys.toList()
                ..sort(
                  (a, b) => _sortOption == TimelineSortOption.newestFirst
                      ? b.compareTo(a)
                      : a.compareTo(b),
                );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _TimelineResultCard(
                    resultCount: visibleItems.length,
                    dayCount: days.length,
                    filterLabel: selectedFilter.label,
                    rangeLabel: selectedRange.preset.label,
                    sortLabel: _sortOption.label,
                    searchQuery: _searchQuery,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyTimelineReviewSummary(
                        context,
                        visibleItems: visibleItems,
                        selectedFilter: selectedFilter,
                        selectedRange: selectedRange,
                      ),
                      icon: const Icon(Icons.content_copy_outlined, size: 18),
                      label: const Text('复制复盘摘要'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...days.map(
                    (day) => Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                DateFormat('M月d日 EEEE').format(day),
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${grouped[day]!.length} 条',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...grouped[day]!.map(
                            (event) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TimelineEventCard(event: event),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('时间线加载失败：$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TimelineEventsTableData> _filterAndSortItems(
    List<TimelineEventsTableData> items,
  ) {
    final query = _searchQuery.toLowerCase();
    final filtered = items.where((event) {
      if (query.isEmpty) {
        return true;
      }

      final haystack = <String>[
        event.title,
        event.summary ?? '',
        _eventTypeLabel(event.eventType),
        _eventActionLabel(event.eventAction),
        event.sourceEntityType,
        event.sourceEntityId,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final occurred = a.occurredAt.compareTo(b.occurredAt);
      if (occurred != 0) {
        return _sortOption == TimelineSortOption.newestFirst
            ? -occurred
            : occurred;
      }

      final created = a.createdAt.compareTo(b.createdAt);
      return _sortOption == TimelineSortOption.newestFirst ? -created : created;
    });

    return filtered;
  }

  Future<void> _copyTimelineReviewSummary(
    BuildContext context, {
    required List<TimelineEventsTableData> visibleItems,
    required TimelineFilter selectedFilter,
    required TimelineDateRangeFilter selectedRange,
  }) async {
    final text = buildTimelineReviewSummary(
      events: visibleItems,
      filter: selectedFilter,
      rangeFilter: selectedRange,
      sortLabel: _sortOption.label,
      searchQuery: _searchQuery,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('复盘摘要已复制')));
  }
}

class _TimelineEventCard extends StatelessWidget {
  const _TimelineEventCard({required this.event});

  final TimelineEventsTableData event;

  @override
  Widget build(BuildContext context) {
    final occurredAt = event.occurredAt.toLocal();
    final sourceRoute = _sourceRoute();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/timeline/${event.id}'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TimelineDot(eventType: event.eventType),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(occurredAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        Chip(label: Text(_eventTypeLabel(event.eventType))),
                        Chip(label: Text(_eventActionLabel(event.eventAction))),
                      ],
                    ),
                    if (event.summary != null &&
                        event.summary!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(event.summary!),
                    ],
                    if (sourceRoute != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => context.push(sourceRoute),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('打开原始对象'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _sourceRoute() {
    switch (event.sourceEntityType) {
      case 'schedule':
        return '/schedule/${event.sourceEntityId}';
      case 'todo':
        return '/todo/${event.sourceEntityId}';
      case 'habit':
        return '/habit/${event.sourceEntityId}';
      case 'goal':
        return '/goal/${event.sourceEntityId}';
      case 'anniversary':
        return '/anniversary/${event.sourceEntityId}';
      case 'note':
        return '/note/${event.sourceEntityId}';
      default:
        return null;
    }
  }
}

class _TimelineSummaryCard extends StatelessWidget {
  const _TimelineSummaryCard({required this.summary});

  final AsyncValue<TimelineSummary> summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: summary.when(
          data: (value) => Row(
            children: <Widget>[
              Expanded(
                child: _SummaryMetric(
                  label: '结果数',
                  value: '${value.total}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '今天',
                  value: '${value.today}',
                  color: const Color(0xFF136F63),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '来源对象',
                  value: '${value.distinctSources}',
                  color: const Color(0xFFC06C00),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '类型数',
                  value: '${value.distinctTypes}',
                  color: const Color(0xFF607D8B),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('统计加载失败：$error'),
        ),
      ),
    );
  }
}

class _TimelineResultCard extends StatelessWidget {
  const _TimelineResultCard({
    required this.resultCount,
    required this.dayCount,
    required this.filterLabel,
    required this.rangeLabel,
    required this.sortLabel,
    required this.searchQuery,
  });

  final int resultCount;
  final int dayCount;
  final String filterLabel;
  final String rangeLabel;
  final String sortLabel;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F0E5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '当前结果',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryMetric(
                    label: '事件',
                    value: '$resultCount',
                    color: const Color(0xFF114B45),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '日期',
                    value: '$dayCount',
                    color: const Color(0xFF8A5CF6),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '筛选',
                    value: filterLabel,
                    color: const Color(0xFFB03A2E),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '顺序',
                    value: sortLabel,
                    color: const Color(0xFF607D8B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('范围：$rangeLabel')),
                if (searchQuery.isNotEmpty)
                  Chip(label: Text('关键词：$searchQuery')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
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

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.eventType});

  final String eventType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: _colorForType(eventType),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'schedule':
        return const Color(0xFF136F63);
      case 'todo':
        return const Color(0xFFC06C00);
      case 'habit':
        return const Color(0xFF607D8B);
      case 'goal':
        return const Color(0xFF8A5CF6);
      case 'anniversary':
        return const Color(0xFFB03A2E);
      case 'note':
        return const Color(0xFF5D7A5D);
      default:
        return const Color(0xFF999999);
    }
  }
}

class _EmptyTimelineState extends StatelessWidget {
  const _EmptyTimelineState({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final description = searchQuery.isEmpty
        ? '新增待办、日程、习惯、纪念日、笔记或目标后，时间线会自动显示事件。'
        : '没有找到包含“$searchQuery”的事件，试试更短的关键词或切换筛选条件。';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.timeline,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              searchQuery.isEmpty ? '还没有事件' : '没有匹配的结果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
}

String _eventTypeLabel(String eventType) {
  switch (eventType) {
    case 'schedule':
      return '日程';
    case 'todo':
      return '待办';
    case 'habit':
      return '习惯';
    case 'anniversary':
      return '纪念日';
    case 'goal':
      return '目标';
    case 'note':
      return '笔记';
    default:
      return eventType;
  }
}

String _eventActionLabel(String action) {
  switch (action) {
    case 'created':
      return '创建';
    case 'updated':
      return '更新';
    case 'completed':
      return '完成';
    case 'checked_in':
      return '打卡';
    case 'scheduled':
      return '转日程';
    default:
      return action;
  }
}
