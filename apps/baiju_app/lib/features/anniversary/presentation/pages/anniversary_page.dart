import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum AnniversarySortOption {
  upcomingFirst('最近到来'),
  titleAsc('标题 A-Z'),
  updatedDesc('最近更新');

  const AnniversarySortOption(this.label);

  final String label;
}

class AnniversaryPage extends ConsumerStatefulWidget {
  const AnniversaryPage({super.key});

  @override
  ConsumerState<AnniversaryPage> createState() => _AnniversaryPageState();
}

class _AnniversaryPageState extends ConsumerState<AnniversaryPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  AnniversaryReminderOption _selectedReminder = AnniversaryReminderOption.three;
  String? _selectedCategory;
  AnniversarySortOption _sortOption = AnniversarySortOption.upcomingFirst;
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(anniversarySummaryProvider);
    final anniversaries = ref.watch(anniversaryListProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('纪念日', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '记录重要日期，提前提醒，不错过每一个值得纪念的时刻。',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _AnniversarySummaryCard(
            summary: summary,
            onTapAll: () => setState(() {
              _selectedCategory = null;
              _sortOption = AnniversarySortOption.upcomingFirst;
            }),
            onTapUpcoming: () => setState(() {
              _selectedCategory = null;
              _sortOption = AnniversarySortOption.upcomingFirst;
            }),
            onTapWithReminder: () => setState(() {
              _sortOption = AnniversarySortOption.upcomingFirst;
            }),
          ),
          const SizedBox(height: 16),
          _UpcomingSprintCard(
            summary: summary,
            selectedCategory: _selectedCategory,
            searchQuery: _searchController.text.trim(),
            onOpenUpcoming: () => context.push('/anniversary/upcoming'),
            onClearFilters:
                (_selectedCategory == null &&
                    _searchController.text.trim().isEmpty)
                ? null
                : () {
                    _searchController.clear();
                    setState(() => _selectedCategory = null);
                  },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/anniversary/upcoming'),
              icon: const Icon(Icons.upcoming_outlined),
              label: const Text('查看即将到来'),
            ),
          ),
          const SizedBox(height: 12),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索纪念日',
            hintText: '按标题或备注搜索',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _QuickCreateAnniversaryCard(
            titleController: _titleController,
            categoryController: _categoryController,
            noteController: _noteController,
            selectedDate: _selectedDate,
            selectedReminder: _selectedReminder,
            isCreating: _isCreating,
            onPickDate: _pickDate,
            onReminderChanged: (value) =>
                setState(() => _selectedReminder = value),
            onSubmit: _createAnniversary,
          ),
          const SizedBox(height: 16),
          anniversaries.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyAnniversaryState();
              }

              final categories =
                  items
                      .map((item) => item.category)
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort();
              final normalizedSearch = _searchController.text
                  .trim()
                  .toLowerCase();
              final sorted = items.toList()
                ..sort(
                  (a, b) => daysUntilNextAnniversary(
                    a.baseDate,
                  ).compareTo(daysUntilNextAnniversary(b.baseDate)),
                );
              final filtered = sorted.where((item) {
                final matchesCategory =
                    _selectedCategory == null ||
                    item.category == _selectedCategory;
                if (!matchesCategory) {
                  return false;
                }
                if (normalizedSearch.isEmpty) {
                  return true;
                }
                return item.title.toLowerCase().contains(normalizedSearch) ||
                    (item.note?.toLowerCase().contains(normalizedSearch) ??
                        false);
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (categories.isNotEmpty) ...<Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        ChoiceChip(
                          label: const Text('全部分类'),
                          selected: _selectedCategory == null,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = null),
                        ),
                        ...categories.map(
                          (category) => ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = category),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  SelectionChipBar<AnniversarySortOption>(
                    values: AnniversarySortOption.values,
                    selected: _sortOption,
                    labelBuilder: (option) => option.label,
                    onSelected: (option) =>
                        setState(() => _sortOption = option),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const Text('当前筛选条件下没有纪念日。')
                  else
                    Column(
                      children:
                          (filtered.toList()..sort((left, right) {
                                switch (_sortOption) {
                                  case AnniversarySortOption.upcomingFirst:
                                    return daysUntilNextAnniversary(
                                      left.baseDate,
                                    ).compareTo(
                                      daysUntilNextAnniversary(right.baseDate),
                                    );
                                  case AnniversarySortOption.titleAsc:
                                    return left.title.compareTo(right.title);
                                  case AnniversarySortOption.updatedDesc:
                                    return right.updatedAt.compareTo(
                                      left.updatedAt,
                                    );
                                }
                              }))
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _AnniversaryListTile(
                                    anniversary: item,
                                    onTap: () =>
                                        context.push('/anniversary/${item.id}'),
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
            error: (error, stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('纪念日加载失败：$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createAnniversary() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isCreating) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isCreating = true);

    try {
      await ref
          .read(anniversaryActionsProvider)
          .createAnniversary(
            title: title,
            baseDate: _selectedDate,
            reminder: _selectedReminder,
            category: _categoryController.text.trim(),
            note: _noteController.text.trim(),
          );
      if (mounted) {
        _titleController.clear();
        _categoryController.clear();
        _noteController.clear();
        setState(() {
          _selectedDate = DateTime.now();
          _selectedReminder = AnniversaryReminderOption.three;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增纪念日失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

class _AnniversarySummaryCard extends StatelessWidget {
  const _AnniversarySummaryCard({
    required this.summary,
    required this.onTapAll,
    required this.onTapUpcoming,
    required this.onTapWithReminder,
  });

  final AsyncValue<AnniversarySummary> summary;
  final VoidCallback onTapAll;
  final VoidCallback onTapUpcoming;
  final VoidCallback onTapWithReminder;

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
                  label: '总数',
                  value: '${value.total}',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: onTapAll,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '30 天内',
                  value: '${value.upcoming30Days}',
                  color: const Color(0xFF136F63),
                  onTap: onTapUpcoming,
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '已提醒',
                  value: '${value.withReminder}',
                  color: const Color(0xFFC06C00),
                  onTap: onTapWithReminder,
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

class _UpcomingSprintCard extends StatelessWidget {
  const _UpcomingSprintCard({
    required this.summary,
    required this.selectedCategory,
    required this.searchQuery,
    required this.onOpenUpcoming,
    required this.onClearFilters,
  });

  final AsyncValue<AnniversarySummary> summary;
  final String? selectedCategory;
  final String searchQuery;
  final VoidCallback onOpenUpcoming;
  final VoidCallback? onClearFilters;

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
                        '近期纪念日冲刺',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '把最近要到来的重要日期、提醒和筛选状态直接提到主页，减少来回切页。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onOpenUpcoming,
                  icon: const Icon(Icons.upcoming_outlined),
                  label: const Text('即将到来'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            summary.when(
              data: (value) => Row(
                children: <Widget>[
                  Expanded(
                    child: _SummaryMetric(
                      label: '30 天内',
                      value: '${value.upcoming30Days}',
                      color: const Color(0xFFB03A2E),
                    ),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      label: '有提醒',
                      value: '${value.withReminder}',
                      color: const Color(0xFF136F63),
                    ),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      label: '总数',
                      value: '${value.total}',
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
                if (selectedCategory != null)
                  Chip(label: Text('分类：$selectedCategory')),
                if (searchQuery.isNotEmpty)
                  Chip(label: Text('关键词：$searchQuery')),
                if (onClearFilters != null)
                  ActionChip(
                    label: const Text('清空筛选'),
                    onPressed: onClearFilters,
                  ),
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

class _QuickCreateAnniversaryCard extends StatelessWidget {
  const _QuickCreateAnniversaryCard({
    required this.titleController,
    required this.categoryController,
    required this.noteController,
    required this.selectedDate,
    required this.selectedReminder,
    required this.isCreating,
    required this.onPickDate,
    required this.onReminderChanged,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TextEditingController categoryController;
  final TextEditingController noteController;
  final DateTime selectedDate;
  final AnniversaryReminderOption selectedReminder;
  final bool isCreating;
  final Future<void> Function() onPickDate;
  final ValueChanged<AnniversaryReminderOption> onReminderChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('快速新增纪念日', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              enabled: !isCreating,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '例如：爸爸生日 / 入职纪念日',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: categoryController,
                    enabled: !isCreating,
                    decoration: const InputDecoration(
                      labelText: '分类',
                      hintText: '例如：家庭 / 工作',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: isCreating ? null : onPickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(DateFormat('M月d日').format(selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              enabled: !isCreating,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AnniversaryReminderOption.values.map((option) {
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
                label: Text(isCreating ? '保存中' : '新增纪念日'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnniversaryListTile extends StatelessWidget {
  const _AnniversaryListTile({required this.anniversary, required this.onTap});

  final AnniversariesTableData anniversary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseDate = anniversary.baseDate.toLocal();
    final days = daysUntilNextAnniversary(anniversary.baseDate);
    final nextLabel = days == 0 ? '今天' : '$days 天后';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      anniversary.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    nextLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF136F63),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('日期 ${DateFormat('yyyy年M月d日').format(baseDate)}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (anniversary.category != null)
                    Chip(label: Text(anniversary.category!)),
                  Chip(
                    label: Text(
                      AnniversaryReminderOption.fromDays(
                        anniversary.remindDaysBefore,
                      ).label,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAnniversaryState extends StatelessWidget {
  const _EmptyAnniversaryState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.celebration_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('还没有纪念日', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('点击右下角按钮，添加你的第一个纪念日。'),
          ],
        ),
      ),
    );
  }
}
