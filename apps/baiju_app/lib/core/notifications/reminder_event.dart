/// A reminder event emitted by [ReminderTicker] when a notification fires.
class ReminderEvent {
  const ReminderEvent({required this.title, required this.body});

  final String title;
  final String body;
}
