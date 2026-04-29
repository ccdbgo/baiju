import 'package:baiju_app/app/app.dart';
import 'package:baiju_app/app/config/env_dev.dart';
import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/core/notifications/reminder_scheduler.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/today/presentation/providers/today_overview_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders app shell with today sections', (WidgetTester tester) async {
    final now = DateTime.now().toUtc();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final todo = TodosTableData(
      id: 'todo-1',
      userId: 'local_user',
      title: '今天整理需求清单',
      description: null,
      priority: 'urgent_important',
      status: 'open',
      dueAt: now,
      plannedAt: now,
      listName: null,
      goalId: null,
      linkedNoteId: null,
      convertedScheduleId: null,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'synced',
      localVersion: 1,
      remoteVersion: 1,
      lastSyncedAt: now,
      deviceId: 'test-device',
    );
    final schedule = SchedulesTableData(
      id: 'schedule-1',
      userId: 'local_user',
      title: '今天下午产品评审',
      description: null,
      startAt: now,
      endAt: now.add(const Duration(hours: 1)),
      isAllDay: false,
      timezone: 'UTC',
      location: null,
      category: null,
      color: null,
      status: 'planned',
      priority: 'not_urgent_important',
      recurrenceRule: null,
      reminderMinutesBefore: 15,
      sourceTodoId: null,
      linkedNoteId: null,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'synced',
      localVersion: 1,
      remoteVersion: 1,
      lastSyncedAt: now,
      deviceId: 'test-device',
    );
    final habit = HabitsTableData(
      id: 'habit-1',
      userId: 'local_user',
      name: '晚间复盘',
      description: null,
      frequencyType: 'daily',
      frequencyRule: 'daily',
      reminderTime: '20:00',
      goalId: null,
      progressWeight: 1.0,
      startDate: now,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'synced',
      localVersion: 1,
      remoteVersion: 1,
      lastSyncedAt: now,
      deviceId: 'test-device',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          reminderSchedulerProvider.overrideWithValue(
            const NoopReminderScheduler(),
          ),
          scheduleSummaryProvider.overrideWith(
            (ref) => Stream<ScheduleSummary>.value(
              const ScheduleSummary(
                total: 2,
                today: 1,
                upcoming: 1,
                completed: 0,
              ),
            ),
          ),
          habitSummaryProvider.overrideWith(
            (ref) => Stream<HabitSummary>.value(
              const HabitSummary(
                total: 1,
                active: 1,
                checkedToday: 0,
              ),
            ),
          ),
          habitCurrentStreakProvider.overrideWith(
            (ref) => Stream<int>.value(3),
          ),
          todayCompletionRateProvider.overrideWith(
            (ref) => Stream<double>.value(0.5),
          ),
          todayScheduleListProvider.overrideWith(
            (ref) => Stream<List<SchedulesTableData>>.value(
              <SchedulesTableData>[schedule],
            ),
          ),
          habitListProvider.overrideWith(
            (ref) => Stream<List<HabitTodayItem>>.value(
              <HabitTodayItem>[
                HabitTodayItem(
                  habit: habit,
                  checkedToday: false,
                  record: null,
                ),
              ],
            ),
          ),
          todoSummaryProvider.overrideWith(
            (ref) => Stream<TodoSummary>.value(
              const TodoSummary(
                total: 3,
                active: 2,
                today: 1,
                completed: 1,
              ),
            ),
          ),
          todayTodoListProvider.overrideWith(
            (ref) => Stream<List<TodosTableData>>.value(<TodosTableData>[todo]),
          ),
          activeTodoPreviewProvider.overrideWith(
            (ref) => Stream<List<TodosTableData>>.value(<TodosTableData>[todo]),
          ),
        ],
        child: const BaijuApp(environment: devEnvironment),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('今日'), findsWidgets);
    expect(find.text('今日工作台'), findsOneWidget);
    expect(find.text('顶部总览'), findsOneWidget);
    expect(find.text('今日日程'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
