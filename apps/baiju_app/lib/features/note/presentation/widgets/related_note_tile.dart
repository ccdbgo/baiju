import 'package:baiju_app/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RelatedNoteTile extends StatelessWidget {
  const RelatedNoteTile({required this.note, required this.onTap, super.key});

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
          padding: const EdgeInsets.all(16),
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
                  Text(
                    DateFormat('M月d日').format(note.updatedAt.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
