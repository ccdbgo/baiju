enum NoteType {
  note('note', '笔记'),
  diary('diary', '日记'),
  memo('memo', '备忘');

  const NoteType(this.value, this.label);

  final String value;
  final String label;

  static NoteType fromValue(String value) {
    return NoteType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => NoteType.note,
    );
  }
}

enum NoteFilter {
  all('全部'),
  favorites('收藏'),
  note('笔记'),
  diary('日记'),
  memo('备忘');

  const NoteFilter(this.label);

  final String label;
}

class NoteSummary {
  const NoteSummary({
    required this.total,
    required this.favorites,
    required this.diaryCount,
  });

  final int total;
  final int favorites;
  final int diaryCount;
}

class NoteRelationTarget {
  const NoteRelationTarget({required this.entityType, required this.entityId});

  final String entityType;
  final String entityId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is NoteRelationTarget &&
        other.entityType == entityType &&
        other.entityId == entityId;
  }

  @override
  int get hashCode => Object.hash(entityType, entityId);
}
