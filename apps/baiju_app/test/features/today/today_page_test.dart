import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/database/database_provider.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/core/notifications/reminder_scheduler.dart';
import 'package:baiju_app/features/anniversary/domain/anniversary_models.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:baiju_app/features/goal/domain/goal_models.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/note/domain/note_models.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:baiju_app/features/schedule/domain/schedule_filter.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/today/presentation/pages/today_page.dart';
import 'package:baiju_app/features/today/presentation/providers/today_overview_providers.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('today page exposes visible deep links and optional sections', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final todo = TodosTableData(
      id: 'todo-1',
      userId: 'local_user',
      title: '推进今日任务',
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
      title: '项目评审',
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
    final anniversary = AnniversariesTableData(
      id: 'anniversary-1',
      userId: 'local_user',
      title: '妈妈生日',
      baseDate: now.add(const Duration(days: 3)),
      calendarType: 'solar',
      remindDaysBefore: 3,
      category: '家庭',
      note: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'synced',
      localVersion: 1,
      remoteVersion: 1,
      lastSyncedAt: now,
      deviceId: 'test-device',
    );
    final note = NotesTableData(
      id: 'note-1',
      userId: 'local_user',
      title: '复盘笔记',
      content: '今天推进顺利',
      noteType: NoteType.note.value,
      relatedEntityType: null,
      relatedEntityId: null,
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
      syncStatus: 'synced',
      localVersion: 1,
      remoteVersion: 1,
      lastSyncedAt: now,
      deviceId: 'test-device',
    );

    await tester.binding.setSurfaceSize(const Size(1200, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          reminderSchedulerProvider.overrideWithValue(
            const NoopReminderScheduler(),
          ),
          currentUserIsAdminProvider.overrideWith((ref) => true),
          appDisplaySettingsProvider.overrideWith(
            (ref) => Stream<AppDisplaySettings>.value(
              const AppDisplaySettings(
                showTodayHero: true,
                showActiveTodoPreview: true,
                showUpcomingAnniversaries: true,
                showRecentNotes: true,
              ),
            ),
          ),
          scheduleSummaryProvider.overrideWith(
            (ref) => Stream<ScheduleSummary>.value(
              const ScheduleSummary(
                total: 1,
                today: 1,
                upcoming: 1,
                completed: 0,
              ),
            ),
          ),
          habitSummaryProvider.overrideWith(
            (ref) => Stream<HabitSummary>.value(
              const HabitSummary(total: 1, active: 1, checkedToday: 0),
            ),
          ),
          habitCurrentStreakProvider.overrideWith(
            (ref) => Stream<int>.value(4),
          ),
          todayCompletionRateProvider.overrideWith(
            (ref) => Stream<double>.value(0.5),
          ),
          pendingReminderCountProvider.overrideWith(
            (ref) => Future<int>.value(2),
          ),
          todayScheduleListProvider.overrideWith(
            (ref) => Stream<List<SchedulesTableData>>.value(
              <SchedulesTableData>[schedule],
            ),
          ),
          habitListProvider.overrideWith(
            (ref) => Stream<List<HabitTodayItem>>.value(<HabitTodayItem>[
              HabitTodayItem(habit: habit, checkedToday: false, record: null),
            ]),
          ),
          todoSummaryProvider.overrideWith(
            (ref) => Stream<TodoSummary>.value(
              const TodoSummary(total: 1, active: 1, today: 1, completed: 0),
            ),
          ),
          todayTodoListProvider.overrideWith(
            (ref) => Stream<List<TodosTableData>>.value(<TodosTableData>[todo]),
          ),
          activeTodoPreviewProvider.overrideWith(
            (ref) => Stream<List<TodosTableData>>.value(<TodosTableData>[todo]),
          ),
          anniversarySummaryProvider.overrideWith(
            (ref) => Stream<AnniversarySummary>.value(
              const AnniversarySummary(
                total: 1,
                upcoming30Days: 1,
                withReminder: 1,
              ),
            ),
          ),
          upcomingAnniversaryListProvider.overrideWith(
            (ref) => Stream<List<AnniversariesTableData>>.value(
              <AnniversariesTableData>[anniversary],
            ),
          ),
          goalSummaryProvider.overrideWith(
            (ref) => Stream<GoalSummary>.value(
              const GoalSummary(total: 1, active: 1, completed: 0),
            ),
          ),
          noteSummaryProvider.overrideWith(
            (ref) => Stream<NoteSummary>.value(
              const NoteSummary(total: 1, favorites: 0, diaryCount: 2),
            ),
          ),
          recentNoteListProvider.overrideWith(
            (ref) => Stream<List<NotesTableData>>.value(<NotesTableData>[note]),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: TodayPage())),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('即将到来'), findsOneWidget);
    expect(find.text('日记时间轴'), findsOneWidget);
    expect(find.text('用户管理'), findsOneWidget);
    expect(find.text('反馈支持'), findsOneWidget);
    expect(find.textContaining('30 天内 1 个纪念日'), findsOneWidget);
    expect(find.text('临近纪念日'), findsOneWidget);
    expect(find.text('最近笔记'), findsOneWidget);
  });
}
