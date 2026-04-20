import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_relation_chip.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum JournalSortOption {
  newestFirst('最新优先'),
  oldestFirst('最早优先'),
  titleAsc('标题 A-Z');

  const JournalSortOption(this.label);

  final String label;
}

class NoteJournalPage extends ConsumerStatefulWidget {
  const NoteJournalPage({super.key});

  @override
  ConsumerState<NoteJournalPage> createState() => _NoteJournalPageState();
}

class _NoteJournalPageState extends ConsumerState<NoteJournalPage> {
  final TextEditingController _searchController = TextEditingController();
  JournalSortOption _sortOption = JournalSortOption.newestFirst;
  bool _showRelatedOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journals = ref.watch(journalNoteListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('日记时间轴')),
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
                          '按时间回看日记',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '这里把日记按日期聚合展示，支持搜索、顺序切换和仅看有关联对象的记录。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.go('/note'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('笔记主页'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索日记',
            hintText: '按标题或内容搜索',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SelectionChipBar<JournalSortOption>(
            values: JournalSortOption.values,
            selected: _sortOption,
            labelBuilder: (item) => item.label,
            onSelected: (item) => setState(() => _sortOption = item),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilterChip(
                label: const Text('仅看有关联对象'),
                selected: _showRelatedOnly,
                onSelected: (value) => setState(() => _showRelatedOnly = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          journals.when(
            data: (items) {
              final filtered = _filterItems(items);
              final grouped = _groupByDay(filtered);
              final summary = _JournalSummary.from(items, filtered, grouped);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _JournalSummaryCard(
                    summary: summary,
                    activeSort: _sortOption.label,
                    relatedOnly: _showRelatedOnly,
                    keyword: _searchController.text.trim(),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    const _EmptyJournalState()
                  else if (filtered.isEmpty)
                    _EmptyJournalSearchState(
                      searchQuery: _searchController.text.trim(),
                      relatedOnly: _showRelatedOnly,
                    )
                  else
                    ...grouped.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              DateFormat('M月d日 EEEE').format(entry.key),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${entry.value.length} 条记录',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            ...entry.value.map(
                              (note) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _JournalEntryTile(note: note),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  List<NotesTableData> _filterItems(List<NotesTableData> items) {
    final normalizedSearch = _searchController.text.trim().toLowerCase();
    final filtered =
        items.where((note) {
          if (_showRelatedOnly &&
              (note.relatedEntityType == null ||
                  note.relatedEntityId == null)) {
            return false;
          }

          if (normalizedSearch.isEmpty) {
            return true;
          }
          final title = note.title?.toLowerCase() ?? '';
          return title.contains(normalizedSearch) ||
              note.content.toLowerCase().contains(normalizedSearch);
        }).toList()..sort((left, right) {
          switch (_sortOption) {
            case JournalSortOption.newestFirst:
              return right.updatedAt.compareTo(left.updatedAt);
            case JournalSortOption.oldestFirst:
              return left.updatedAt.compareTo(right.updatedAt);
            case JournalSortOption.titleAsc:
              final leftTitle = left.title ?? '';
              final rightTitle = right.title ?? '';
              return leftTitle.compareTo(rightTitle);
          }
        });

    return filtered;
  }

  Map<DateTime, List<NotesTableData>> _groupByDay(List<NotesTableData> items) {
    final grouped = <DateTime, List<NotesTableData>>{};
    for (final note in items) {
      final local = note.updatedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      grouped.putIfAbsent(day, () => <NotesTableData>[]).add(note);
    }

    final entries = grouped.entries.toList()
      ..sort(
        (a, b) => _sortOption == JournalSortOption.oldestFirst
            ? a.key.compareTo(b.key)
            : b.key.compareTo(a.key),
      );

    return Map<DateTime, List<NotesTableData>>.fromEntries(entries);
  }
}

class _JournalSummary {
  const _JournalSummary({
    required this.total,
    required this.visible,
    required this.related,
    required this.days,
    required this.todayCount,
  });

  factory _JournalSummary.from(
    List<NotesTableData> allItems,
    List<NotesTableData> visibleItems,
    Map<DateTime, List<NotesTableData>> grouped,
  ) {
    final today = DateTime.now().toLocal();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final relatedCount = allItems
        .where(
          (note) =>
              note.relatedEntityType != null && note.relatedEntityId != null,
        )
        .length;
    final todayCount = allItems.where((note) {
      final local = note.updatedAt.toLocal();
      return !local.isBefore(todayStart) && local.isBefore(todayEnd);
    }).length;

    return _JournalSummary(
      total: allItems.length,
      visible: visibleItems.length,
      related: relatedCount,
      days: grouped.length,
      todayCount: todayCount,
    );
  }

  final int total;
  final int visible;
  final int related;
  final int days;
  final int todayCount;
}

class _JournalSummaryCard extends StatelessWidget {
  const _JournalSummaryCard({
    required this.summary,
    required this.activeSort,
    required this.relatedOnly,
    required this.keyword,
  });

  final _JournalSummary summary;
  final String activeSort;
  final bool relatedOnly;
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
                    value: '${summary.visible}',
                    color: const Color(0xFF114B45),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '总日记',
                    value: '${summary.total}',
                    color: const Color(0xFF5D7A5D),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '有关联',
                    value: '${summary.related}',
                    color: const Color(0xFFC06C00),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: '日期',
                    value: '${summary.days}',
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
                Chip(label: Text('今天更新：${summary.todayCount}')),
                Chip(label: Text('排序：$activeSort')),
                if (relatedOnly) const Chip(label: Text('仅看有关联对象')),
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

class _JournalEntryTile extends StatelessWidget {
  const _JournalEntryTile({required this.note});

  final NotesTableData note;

  @override
  Widget build(BuildContext context) {
    final title = (note.title == null || note.title!.trim().isEmpty)
        ? '无标题日记'
        : note.title!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/note/${note.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                DateFormat('HH:mm').format(note.updatedAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (note.relatedEntityType != null &&
                        note.relatedEntityId != null) ...<Widget>[
                      NoteRelationChip(note: note),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      note.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
}

class _EmptyJournalState extends StatelessWidget {
  const _EmptyJournalState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.auto_stories_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('还没有日记', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('先创建一篇日记，这里会按时间线自动聚合展示。'),
          ],
        ),
      ),
    );
  }
}

class _EmptyJournalSearchState extends StatelessWidget {
  const _EmptyJournalSearchState({
    required this.searchQuery,
    required this.relatedOnly,
  });

  final String searchQuery;
  final bool relatedOnly;

  @override
  Widget build(BuildContext context) {
    final tips = <String>[
      if (searchQuery.isNotEmpty) '关键词：$searchQuery',
      if (relatedOnly) '仅看有关联对象',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Text('当前筛选下没有日记', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              tips.isEmpty
                  ? '可以调整搜索条件后重试。'
                  : '已应用 ${tips.join(' / ')}，可以放宽条件后再看。',
            ),
          ],
        ),
      ),
    );
  }
}
