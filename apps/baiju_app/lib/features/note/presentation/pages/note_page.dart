import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/note/presentation/widgets/note_relation_chip.dart';
import 'package:baiju_app/shared/widgets/list_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum NoteSortOption {
  updatedDesc('最近更新'),
  titleAsc('标题 A-Z'),
  favoritesFirst('收藏优先');

  const NoteSortOption(this.label);

  final String label;
}

class NotePage extends ConsumerStatefulWidget {
  const NotePage({super.key});

  @override
  ConsumerState<NotePage> createState() => _NotePageState();
}

class _NotePageState extends ConsumerState<NotePage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  NoteType _selectedType = NoteType.note;
  bool _isFavorite = false;
  bool _showOnlyRelated = false;
  NoteSortOption _sortOption = NoteSortOption.updatedDesc;
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(noteSummaryProvider);
    final notes = ref.watch(noteListProvider);
    final selectedFilter = ref.watch(selectedNoteFilterProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('笔记', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('记录想法、日记和备忘，支持收藏和关联其他事项。', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 18),
          _NoteSummaryCard(summary: summary),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/note/journal'),
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('日记时间轴'),
            ),
          ),
          const SizedBox(height: 12),
          _QuickCreateNoteCard(
            titleController: _titleController,
            contentController: _contentController,
            selectedType: _selectedType,
            isFavorite: _isFavorite,
            isCreating: _isCreating,
            onTypeChanged: (value) => setState(() => _selectedType = value),
            onFavoriteChanged: (value) => setState(() => _isFavorite = value),
            onSubmit: _createNote,
          ),
          const SizedBox(height: 16),
          ModuleSearchField(
            controller: _searchController,
            labelText: '搜索笔记',
            hintText: '按标题或内容搜索',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _showOnlyRelated,
            contentPadding: EdgeInsets.zero,
            title: const Text('仅看有关联对象的笔记'),
            onChanged: (value) => setState(() => _showOnlyRelated = value),
          ),
          const SizedBox(height: 4),
          SelectionChipBar<NoteSortOption>(
            values: NoteSortOption.values,
            selected: _sortOption,
            labelBuilder: (option) => option.label,
            onSelected: (option) => setState(() => _sortOption = option),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NoteFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(filter.label),
                selected: filter == selectedFilter,
                onSelected: (_) => ref
                    .read(selectedNoteFilterProvider.notifier)
                    .select(filter),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          notes.when(
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyNoteState();
              }
              final normalizedSearch = _searchController.text
                  .trim()
                  .toLowerCase();
              final filtered = items.where((note) {
                final matchesRelated =
                    !_showOnlyRelated ||
                    (note.relatedEntityType != null &&
                        note.relatedEntityId != null);
                if (!matchesRelated) {
                  return false;
                }
                if (normalizedSearch.isEmpty) {
                  return true;
                }
                final title = note.title?.toLowerCase() ?? '';
                return title.contains(normalizedSearch) ||
                    note.content.toLowerCase().contains(normalizedSearch);
              }).toList();
              final sorted = filtered.toList()
                ..sort((left, right) {
                  switch (_sortOption) {
                    case NoteSortOption.updatedDesc:
                      return right.updatedAt.compareTo(left.updatedAt);
                    case NoteSortOption.titleAsc:
                      final leftTitle = left.title ?? '';
                      final rightTitle = right.title ?? '';
                      return leftTitle.compareTo(rightTitle);
                    case NoteSortOption.favoritesFirst:
                      final favoriteDiff = (right.isFavorite ? 1 : 0).compareTo(
                        left.isFavorite ? 1 : 0,
                      );
                      if (favoriteDiff != 0) {
                        return favoriteDiff;
                      }
                      return right.updatedAt.compareTo(left.updatedAt);
                  }
                });

              return Column(
                children: sorted.isEmpty
                    ? const <Widget>[Text('当前筛选条件下没有笔记。')]
                    : sorted
                          .map(
                            (note) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _NoteListTile(
                                note: note,
                                onTap: () => context.push('/note/${note.id}'),
                              ),
                            ),
                          )
                          .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text('笔记加载失败：$error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (_isCreating || (title.isEmpty && content.isEmpty)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isCreating = true);

    try {
      await ref
          .read(noteActionsProvider)
          .createNote(
            title: title,
            content: content,
            noteType: _selectedType,
            isFavorite: _isFavorite,
          );
      if (mounted) {
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _selectedType = NoteType.note;
          _isFavorite = false;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('新增笔记失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

class _NoteSummaryCard extends StatelessWidget {
  const _NoteSummaryCard({required this.summary});

  final AsyncValue<NoteSummary> summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: summary.when(
          data: (value) => Row(
            children: <Widget>[
              Expanded(
                child: _NoteMetric(
                  label: '总数',
                  value: '${value.total}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Expanded(
                child: _NoteMetric(
                  label: '收藏',
                  value: '${value.favorites}',
                  color: const Color(0xFFC06C00),
                ),
              ),
              Expanded(
                child: _NoteMetric(
                  label: '日记',
                  value: '${value.diaryCount}',
                  color: const Color(0xFF136F63),
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

class _NoteMetric extends StatelessWidget {
  const _NoteMetric({
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

class _QuickCreateNoteCard extends StatelessWidget {
  const _QuickCreateNoteCard({
    required this.titleController,
    required this.contentController,
    required this.selectedType,
    required this.isFavorite,
    required this.isCreating,
    required this.onTypeChanged,
    required this.onFavoriteChanged,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;
  final NoteType selectedType;
  final bool isFavorite;
  final bool isCreating;
  final ValueChanged<NoteType> onTypeChanged;
  final ValueChanged<bool> onFavoriteChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('快速新增笔记', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              enabled: !isCreating,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              enabled: !isCreating,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '内容',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: NoteType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.label),
                  selected: type == selectedType,
                  onSelected: isCreating ? null : (_) => onTypeChanged(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: isFavorite,
              contentPadding: EdgeInsets.zero,
              title: const Text('创建时直接收藏'),
              onChanged: isCreating ? null : onFavoriteChanged,
            ),
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
                label: Text(isCreating ? '保存中' : '新增笔记'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteListTile extends StatelessWidget {
  const _NoteListTile({required this.note, required this.onTap});

  final NotesTableData note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (note.title == null || note.title!.trim().isEmpty)
        ? '无标题笔记'
        : note.title!;

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
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (note.isFavorite)
                    const Icon(Icons.star, color: Color(0xFFC06C00)),
                ],
              ),
              const SizedBox(height: 8),
              Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(label: Text(NoteType.fromValue(note.noteType).label)),
                  if (note.relatedEntityType != null &&
                      note.relatedEntityId != null)
                    NoteRelationChip(note: note),
                  Chip(
                    label: Text(
                      DateFormat('M月d日 HH:mm').format(note.updatedAt.toLocal()),
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

class _EmptyNoteState extends StatelessWidget {
  const _EmptyNoteState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.note_alt_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('还没有笔记', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('点击右下角按钮，记录你的第一条笔记。'),
          ],
        ),
      ),
    );
  }
}
