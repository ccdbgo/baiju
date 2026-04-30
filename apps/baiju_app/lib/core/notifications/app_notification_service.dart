import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/notifications/reminder_scheduler.dart';
import 'package:baiju_app/features/weather/domain/weather_models.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class AppNotificationService implements ReminderScheduler {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: '白驹',
      appUserModelId: 'com.baiju.baiju_app',
      guid: 'a8b9c0d1-e2f3-4a5b-6c7d-8e9f0a1b2c3d',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(settings: settings);
    await _requestPermissions();
    _initialized = true;
  }

  @override
  Future<void> syncScheduleReminder(SchedulesTableData schedule) async {
    await cancelScheduleReminder(schedule.id);

    if (!_initialized ||
        schedule.status != 'planned' ||
        schedule.reminderMinutesBefore == null) {
      return;
    }

    final reminderAt = schedule.startAt.subtract(
      Duration(minutes: schedule.reminderMinutesBefore!),
    );
    if (!reminderAt.isAfter(DateTime.now().toUtc())) {
      return;
    }

    await _plugin.zonedSchedule(
      id: _notificationId('schedule', schedule.id),
      title: '日程提醒',
      body: schedule.title,
      scheduledDate: tz.TZDateTime.from(reminderAt, tz.UTC),
      notificationDetails: _defaultDetails(
        channelId: 'baiju_schedule',
        channelName: '日程提醒',
        channelDescription: '白驹的日程提醒通知',
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'schedule:${schedule.id}',
    );
  }

  @override
  Future<void> syncHabitReminder(HabitsTableData habit) async {
    await cancelHabitReminder(habit.id);

    if (!_initialized ||
        habit.status != 'active' ||
        habit.reminderTime == null ||
        habit.reminderTime!.isEmpty) {
      return;
    }

    final parts = habit.reminderTime!.split(':');
    if (parts.length != 2) {
      return;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return;
    }

    final nowLocal = DateTime.now();
    var nextLocal =
        DateTime(nowLocal.year, nowLocal.month, nowLocal.day, hour, minute);
    if (!nextLocal.isAfter(nowLocal)) {
      nextLocal = nextLocal.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _notificationId('habit', habit.id),
      title: '习惯提醒',
      body: habit.name,
      scheduledDate: tz.TZDateTime.from(nextLocal.toUtc(), tz.UTC),
      notificationDetails: _defaultDetails(
        channelId: 'baiju_habit',
        channelName: '习惯提醒',
        channelDescription: '白驹的习惯提醒通知',
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'habit:${habit.id}',
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> syncAllReminders({
    required Iterable<SchedulesTableData> schedules,
    required Iterable<HabitsTableData> habits,
    required Iterable<TodosTableData> todos,
  }) async {
    await cancelAllManagedReminders();

    if (!_initialized) {
      return;
    }

    for (final schedule in schedules) {
      await syncScheduleReminder(schedule);
    }
    for (final habit in habits) {
      await syncHabitReminder(habit);
    }
    for (final todo in todos) {
      await syncTodoReminder(todo);
    }
  }

  @override
  Future<void> syncTodoReminder(TodosTableData todo) async {
    await cancelTodoReminder(todo.id);

    if (!_initialized) {
      return;
    }

    final dueAt = todo.dueAt;
    if (dueAt == null || todo.status == 'completed' || todo.status == 'archived') {
      return;
    }

    // Default: remind 30 minutes before due time
    final reminderAt = dueAt.subtract(const Duration(minutes: 30));
    if (!reminderAt.isAfter(DateTime.now().toUtc())) {
      return;
    }

    await _plugin.zonedSchedule(
      id: _notificationId('todo', todo.id),
      title: '待办提醒',
      body: todo.title,
      scheduledDate: tz.TZDateTime.from(reminderAt, tz.UTC),
      notificationDetails: _defaultDetails(
        channelId: 'baiju_todo',
        channelName: '待办提醒',
        channelDescription: '白驹的待办提醒通知',
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'todo:${todo.id}',
    );
  }

  @override
  Future<void> cancelTodoReminder(String todoId) {
    return _plugin.cancel(id: _notificationId('todo', todoId));
  }

  @override
  Future<void> cancelScheduleReminder(String scheduleId) {
    return _plugin.cancel(id: _notificationId('schedule', scheduleId));
  }

  @override
  Future<void> cancelHabitReminder(String habitId) {
    return _plugin.cancel(id: _notificationId('habit', habitId));
  }

  @override
  Future<void> cancelAllManagedReminders() {
    return _plugin.cancelAll();
  }

  @override
  Future<List<PendingNotificationRequest>> pendingReminderRequests() {
    return _plugin.pendingNotificationRequests();
  }

  Future<void> showImmediate({
    required String id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'baiju_reminder',
          '提醒',
          channelDescription: '白驹的即时提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(actions: []),
      ),
      payload: payload,
    );
  }

  Future<void> showWeatherAlert(WeatherInfo info) async {
    if (!_initialized || !info.hasSevereAlert) return;
    await _plugin.show(
      id: 'weather:alert'.hashCode & 0x7fffffff,
      title: '恶劣天气提醒',
      body: info.alertMessage,
      notificationDetails: _defaultDetails(
        channelId: 'baiju_weather',
        channelName: '天气预警',
        channelDescription: '白驹的恶劣天气提醒通知',
      ),
      payload: 'weather:alert',
    );
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  NotificationDetails _defaultDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(
        actions: [],
      ),
    );
  }

  int _notificationId(String type, String entityId) {
    return '$type:$entityId'.hashCode & 0x7fffffff;
  }
}
