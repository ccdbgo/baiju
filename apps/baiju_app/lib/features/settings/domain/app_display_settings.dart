class AppDisplaySettings {
  const AppDisplaySettings({
    this.showTodayHero = true,
    this.showActiveTodoPreview = true,
    this.showUpcomingAnniversaries = true,
    this.showRecentNotes = true,
  });

  final bool showTodayHero;
  final bool showActiveTodoPreview;
  final bool showUpcomingAnniversaries;
  final bool showRecentNotes;

  AppDisplaySettings copyWith({
    bool? showTodayHero,
    bool? showActiveTodoPreview,
    bool? showUpcomingAnniversaries,
    bool? showRecentNotes,
  }) {
    return AppDisplaySettings(
      showTodayHero: showTodayHero ?? this.showTodayHero,
      showActiveTodoPreview:
          showActiveTodoPreview ?? this.showActiveTodoPreview,
      showUpcomingAnniversaries:
          showUpcomingAnniversaries ?? this.showUpcomingAnniversaries,
      showRecentNotes: showRecentNotes ?? this.showRecentNotes,
    );
  }
}
