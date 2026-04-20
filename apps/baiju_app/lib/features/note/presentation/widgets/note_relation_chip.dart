import 'package:baiju_app/core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NoteRelationChip extends StatelessWidget {
  const NoteRelationChip({required this.note, super.key});

  final NotesTableData note;

  @override
  Widget build(BuildContext context) {
    if (note.relatedEntityType == null || note.relatedEntityId == null) {
      return const SizedBox.shrink();
    }

    final route = _relationRoute(note);
    return ActionChip(
      avatar: Icon(_relationIcon(note.relatedEntityType!), size: 16),
      label: Text(_relationLabel(note.relatedEntityType!)),
      onPressed: route == null ? null : () => context.push(route),
    );
  }

  String? _relationRoute(NotesTableData note) {
    switch (note.relatedEntityType) {
      case 'todo':
        return '/todo/${note.relatedEntityId}';
      case 'schedule':
        return '/schedule/${note.relatedEntityId}';
      case 'habit':
        return '/habit/${note.relatedEntityId}';
      case 'goal':
        return '/goal/${note.relatedEntityId}';
      case 'anniversary':
        return '/anniversary/${note.relatedEntityId}';
      default:
        return null;
    }
  }

  String _relationLabel(String type) {
    switch (type) {
      case 'todo':
        return '关联待办';
      case 'schedule':
        return '关联日程';
      case 'habit':
        return '关联习惯';
      case 'goal':
        return '关联目标';
      case 'anniversary':
        return '关联纪念日';
      default:
        return '关联对象';
    }
  }

  IconData _relationIcon(String type) {
    switch (type) {
      case 'todo':
        return Icons.checklist_outlined;
      case 'schedule':
        return Icons.event_outlined;
      case 'habit':
        return Icons.bolt_outlined;
      case 'goal':
        return Icons.flag_outlined;
      case 'anniversary':
        return Icons.celebration_outlined;
      default:
        return Icons.link_outlined;
    }
  }
}
