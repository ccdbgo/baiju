import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum UpcomingAnniversaryFilter {
  next7Days('7 天内', 7),
  next30Days('30 天内', 30),
  all('全部', 3650);

  const UpcomingAnniversaryFilter(this.label, this.maxDays);

  final String label;
  final int maxDays;
}

enum UpcomingAnniversarySortOption {
  daysAsc('最近到来'),
  titleAsc('标题 A-Z'),
  categoryAsc('分类');

  const UpcomingAnniversarySortOption(this.label);

  final String label;
}

class AnniversaryUpcomingPage extends ConsumerStatefulWidget {
  const AnniversaryUpcomingPage({super.key});

  @override
  ConsumerState<AnniversaryUpcomingPage> createState() =>
      _AnniversaryUpcomingPageState();
}

class _AnniversaryUpcomingPageState
    extends ConsumerState<AnniversaryUpcomingPage> {
  final TextEditingController _searchController = TextEditingController();
  UpcomingAnniversaryFilter _filter = UpcomingAnniversaryFilter.next30Days;
  UpcomingAnniversarySortOption _sortOption =
      UpcomingAnniversarySortOption.daysAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anniversaries = ref.watch(anniversaryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('即将到来')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Card(
            color: const Color(0xFFF5F0E5),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '近期纪念日冲刺',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '这里集中查看最近要到来的纪念日，支持关键词筛选、范围切换和分类排序。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/anniversary'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('纪念日主页'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索纪念日',
            hintText: '按标题、分类或备注筛选',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SelectionChipBar<UpcomingAnniversaryFilter>(
            values: UpcomingAnniversaryFilter.values,
            selected: _filter,
            labelBuilder: (item) => item.label,
            onSelected: (item) => setState(() => _filter = item),
          ),
          const SizedBox(height: 12),
          SelectionChipBar<UpcomingAnniversarySortOption>(
            values: UpcomingAnniversarySortOption.values,
            selected: _sortOption,
            labelBuilder: (item) => item.label,
            onSelected: (item) => setState(() => _sortOption = item),
          ),
          const SizedBox(height: 16),
          anniversaries.when(
            data: (items) {
              final summary = _buildSummary(items);
              final filtered = _filterItems(items);

              return Column(
                children: <Widget>[
                  _UpcomingSummaryCard(
                    summary: summary,
                    visibleCount: filtered.length,
                    activeFilter: _filter.label,
                    activeSort: _sortOption.label,
                    keyword: _searchController.text.trim(),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    _EmptyUpcomingState(
                      searchQuery: _searchController.text.trim(),
                    )
                  else
                    Column(
                      children: filtered
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _UpcomingAnniversaryTile(
                                anniversary: item,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text('加载失败：$error'),
          ),
        ],
      ),
    );
  }

  _UpcomingSummary _buildSummary(List<AnniversariesTableData> items) {
    var within7Days = 0;
    var within30Days = 0;
    final categories = <String>{};

    for (final item in items) {
      final days = daysUntilNextAnniversary(item.baseDate);
      if (days >= 0 && days <= 7) {
        within7Days++;
      }
      if (days >= 0 && days <= 30) {
        within30Days++;
      }
      if (item.category != null && item.category!.trim().isNotEmpty) {
        categories.add(item.category!.trim());
      }
    }

    return _UpcomingSummary(
      total: items.length,
      within7Days: within7Days,
      within30Days: within30Days,
      categoryCount: categories.length,
    );
  }

  List<AnniversariesTableData> _filterItems(
    List<AnniversariesTableData> items,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = items.where((item) {
      final days = daysUntilNextAnniversary(item.baseDate);
      if (days < 0 || days > _filter.maxDays) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }

      final haystack = <String>[
        item.title,
        item.category ?? '',
        item.note ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case UpcomingAnniversarySortOption.daysAsc:
          return daysUntilNextAnniversary(
            a.baseDate,
          ).compareTo(daysUntilNextAnniversary(b.baseDate));
        case UpcomingAnniversarySortOption.titleAsc:
          return a.title.compareTo(b.title);
        case UpcomingAnniversarySortOption.categoryAsc:
          final leftCategory = a.category ?? '未分类';
          final rightCategory = b.category ?? '未分类';
          final diff = leftCategory.compareTo(rightCategory);
          if (diff != 0) {
            return diff;
          }
          return a.title.compareTo(b.title);
      }
    });

    return filtered;
  }
}

class _UpcomingSummary {
  const _UpcomingSummary({
    required this.total,
    required this.within7Days,
    required this.within30Days,
    required this.categoryCount,
  });

  final int total;
  final int within7Days;
  final int within30Days;
  final int categoryCount;
}

class _UpcomingSummaryCard extends StatelessWidget {
  const _UpcomingSummaryCard({
    required this.summary,
    required this.visibleCount,
    required this.activeFilter,
    required this.activeSort,
    required this.keyword,
  });

  final _UpcomingSummary summary;
  final int visibleCount;
  final String activeFilter;
  final String activeSort;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('当前结果', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryMetric(
                    label: '结果数',
                    value: '$visibleCount',
                    color: const Color(0xFF114B45),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '7 天内',
                    value: '${summary.within7Days}',
                    color: const Color(0xFFB03A2E),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '30 天内',
                    value: '${summary.within30Days}',
                    color: const Color(0xFFC06C00),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '分类',
                    value: '${summary.categoryCount}',
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
                Chip(label: Text('范围：$activeFilter')),
                Chip(label: Text('排序：$activeSort')),
                Chip(label: Text('全部：${summary.total}')),
                if (keyword.isNotEmpty) Chip(label: Text('关键词：$keyword')),
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

class _UpcomingAnniversaryTile extends StatelessWidget {
  const _UpcomingAnniversaryTile({required this.anniversary});

  final AnniversariesTableData anniversary;

  @override
  Widget build(BuildContext context) {
    final days = daysUntilNextAnniversary(anniversary.baseDate);
    final date = anniversary.baseDate.toLocal();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/anniversary/${anniversary.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFB03A2E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.celebration_outlined,
                  color: Color(0xFFB03A2E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      anniversary.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(DateFormat('yyyy年M月d日').format(date)),
                    if (anniversary.category != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        anniversary.category!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                days == 0 ? '今天' : '$days 天后',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF136F63),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyUpcomingState extends StatelessWidget {
  const _EmptyUpcomingState({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.upcoming_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              searchQuery.isEmpty ? '当前范围内没有纪念日' : '没有匹配的纪念日',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isEmpty
                  ? '可以切换筛选范围，或者先添加新的重要日期。'
                  : '试试更短的关键词，或者切换范围和排序方式。',
            ),
          ],
        ),
      ),
    );
  }
}
