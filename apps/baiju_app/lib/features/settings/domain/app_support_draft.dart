enum SupportCategory {
  feedback('feedback', '功能建议'),
  bug('bug', 'Bug 反馈'),
  sponsor('sponsor', '赞助咨询'),
  other('other', '其他');

  const SupportCategory(this.value, this.label);

  final String value;
  final String label;

  static SupportCategory fromValue(String? value) {
    return SupportCategory.values.firstWhere(
      (item) => item.value == value,
      orElse: () => SupportCategory.feedback,
    );
  }
}

class AppSupportDraft {
  const AppSupportDraft({
    this.category = SupportCategory.feedback,
    this.contact = '',
    this.message = '',
  });

  final SupportCategory category;
  final String contact;
  final String message;

  AppSupportDraft copyWith({
    SupportCategory? category,
    String? contact,
    String? message,
  }) {
    return AppSupportDraft(
      category: category ?? this.category,
      contact: contact ?? this.contact,
      message: message ?? this.message,
    );
  }
}
