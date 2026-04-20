import 'package:baiju_app/features/anniversary/presentation/pages/anniversary_detail_page.dart';
import 'package:baiju_app/features/anniversary/presentation/pages/anniversary_page.dart';
import 'package:baiju_app/features/anniversary/presentation/pages/anniversary_upcoming_page.dart';
import 'package:baiju_app/features/goal/presentation/pages/goal_page.dart';
import 'package:baiju_app/features/goal/presentation/pages/goal_detail_page.dart';
import 'package:baiju_app/features/goal/presentation/pages/goal_habits_page.dart';
import 'package:baiju_app/features/goal/presentation/pages/goal_todos_page.dart';
import 'package:baiju_app/features/habit/presentation/pages/habit_detail_page.dart';
import 'package:baiju_app/features/habit/presentation/pages/habit_page.dart';
import 'package:baiju_app/features/note/presentation/pages/note_detail_page.dart';
import 'package:baiju_app/features/note/presentation/pages/note_journal_page.dart';
import 'package:baiju_app/features/note/presentation/pages/note_page.dart';
import 'package:baiju_app/features/schedule/presentation/pages/schedule_detail_page.dart';
import 'package:baiju_app/features/schedule/presentation/pages/schedule_page.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_about_page.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_account_sync_page.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_general_page.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_notifications_page.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_page.dart';
import 'package:baiju_app/features/settings/presentation/pages/settings_support_page.dart';
import 'package:baiju_app/features/timeline/presentation/pages/timeline_page.dart';
import 'package:baiju_app/features/timeline/presentation/pages/timeline_event_detail_page.dart';
import 'package:baiju_app/features/today/presentation/pages/today_page.dart';
import 'package:baiju_app/features/todo/presentation/pages/todo_detail_page.dart';
import 'package:baiju_app/features/todo/presentation/pages/todo_page.dart';
import 'package:baiju_app/features/user/presentation/pages/login_page.dart';
import 'package:baiju_app/features/user/presentation/pages/register_page.dart';
import 'package:baiju_app/features/user/presentation/pages/user_overview_page.dart';
import 'package:baiju_app/shared/widgets/app_shell.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  const AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            const NoTransitionPage<void>(child: LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            const NoTransitionPage<void>(child: RegisterPage()),
      ),
      GoRoute(
        path: '/overview',
        pageBuilder: (context, state) =>
            const NoTransitionPage<void>(child: UserOverviewPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/today',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: TodayPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/schedule',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: SchedulePage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':scheduleId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: ScheduleDetailPage(
                        scheduleId: state.pathParameters['scheduleId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/todo',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: TodoPage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':todoId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: TodoDetailPage(
                        todoId: state.pathParameters['todoId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/habit',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: HabitPage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':habitId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: HabitDetailPage(
                        habitId: state.pathParameters['habitId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/anniversary',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: AnniversaryPage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'upcoming',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: AnniversaryUpcomingPage(),
                        ),
                  ),
                  GoRoute(
                    path: ':anniversaryId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: AnniversaryDetailPage(
                        anniversaryId: state.pathParameters['anniversaryId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/goal',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: GoalPage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':goalId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: GoalDetailPage(
                        goalId: state.pathParameters['goalId']!,
                      ),
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'todos',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: GoalTodosPage(
                            goalId: state.pathParameters['goalId']!,
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'habits',
                        pageBuilder: (context, state) => NoTransitionPage<void>(
                          child: GoalHabitsPage(
                            goalId: state.pathParameters['goalId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/note',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: NotePage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'journal',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(child: NoteJournalPage()),
                  ),
                  GoRoute(
                    path: ':noteId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: NoteDetailPage(
                        noteId: state.pathParameters['noteId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/timeline',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: TimelinePage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':eventId',
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      child: TimelineEventDetailPage(
                        eventId: state.pathParameters['eventId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage<void>(child: SettingsPage()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'account',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: SettingsAccountSyncPage(),
                        ),
                  ),
                  GoRoute(
                    path: 'notifications',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: SettingsNotificationsPage(),
                        ),
                  ),
                  GoRoute(
                    path: 'general',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: SettingsGeneralPage(),
                        ),
                  ),
                  GoRoute(
                    path: 'about',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: SettingsAboutPage(),
                        ),
                  ),
                  GoRoute(
                    path: 'support',
                    pageBuilder: (context, state) =>
                        const NoTransitionPage<void>(
                          child: SettingsSupportPage(),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/user', redirect: (context, state) => '/settings/account'),
    ],
  );
}
