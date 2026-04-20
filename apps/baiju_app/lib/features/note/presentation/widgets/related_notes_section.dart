import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/note/presentation/widgets/related_note_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RelatedNotesSection extends StatelessWidget {
  const RelatedNotesSection({
    required this.relatedNotes,
    required this.onCreate,
    required this.onOpenNote,
    this.title = '关联笔记',
    this.emptyText = '还没有关联笔记',
    super.key,
  });

  final AsyncValue<List<NotesTableData>> relatedNotes;
  final VoidCallback onCreate;
  final ValueChanged<NotesTableData> onOpenNote;
  final String title;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('新增关联笔记'),
        ),
        const SizedBox(height: 12),
        relatedNotes.when(
          data: (items) {
            if (items.isEmpty) {
              return Text(emptyText);
            }
            return Column(
              children: items
                  .map(
                    (note) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: RelatedNoteTile(
                        note: note,
                        onTap: () => onOpenNote(note),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => Text('关联笔记加载失败：$error'),
        ),
      ],
    );
  }
}
