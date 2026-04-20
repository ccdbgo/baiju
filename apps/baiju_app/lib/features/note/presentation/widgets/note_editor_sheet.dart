import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:flutter/material.dart';

class NoteEditorResult {
  const NoteEditorResult({
    required this.title,
    required this.content,
    required this.noteType,
    required this.isFavorite,
  });

  final String title;
  final String content;
  final NoteType noteType;
  final bool isFavorite;
}

Future<NoteEditorResult?> showNoteEditorSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialTitle = '',
  String initialContent = '',
  NoteType initialType = NoteType.note,
  bool initialFavorite = false,
}) async {
  final titleController = TextEditingController(text: initialTitle);
  final contentController = TextEditingController(text: initialContent);
  var selectedType = initialType;
  var isFavorite = initialFavorite;

  try {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      minLines: 4,
                      maxLines: 6,
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
                          onSelected: (_) =>
                              setModalState(() => selectedType = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      value: isFavorite,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('收藏'),
                      onChanged: (value) =>
                          setModalState(() => isFavorite = value),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return null;
    }

    return NoteEditorResult(
      title: titleController.text.trim(),
      content: contentController.text.trim(),
      noteType: selectedType,
      isFavorite: isFavorite,
    );
  } finally {
    titleController.dispose();
    contentController.dispose();
  }
}
