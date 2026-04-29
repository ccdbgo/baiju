import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/notifications/app_notification_service.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/anniversary/presentation/providers/anniversary_providers.dart';
import 'package:baiju_app/features/goal/presentation/providers/goal_providers.dart';
import 'package:baiju_app/features/habit/domain/habit_models.dart';
import 'package:baiju_app/features/habit/presentation/providers/habit_providers.dart';
import 'package:baiju_app/features/note/presentation/providers/note_providers.dart';
import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:baiju_app/features/schedule/presentation/providers/schedule_providers.dart';
import 'package:baiju_app/features/today/presentation/providers/today_overview_providers.dart';
import 'package:baiju_app/features/today/presentation/widgets/today_overview_card.dart';
import 'package:baiju_app/features/todo/domain/todo_filter.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:baiju_app/features/weather/presentation/providers/weather_providers.dart';
import 'package:baiju_app/features/weather/presentation/widgets/weather_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  final Set<String> _pendingTodoIds = <String>{};
  final Set<String> _pendingScheduleIds = <String>{};
  final Set<String> _pendingHabitIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(todoSummaryProvider);
    final scheduleSummary = ref.watch(scheduleSummaryProvider);
    final habitSummary = ref.watch(habitSummaryProvider);
    final habitCurrentStreak = ref.watch(habitCurrentStreakProvider);
    final completionRate = ref.watch(todayCompletionRateProvider);
    final pendingReminderCount = ref.watch(pendingReminderCountProvider);
    final todaySchedules = ref.watch(todayScheduleListProvider);
    final todayTodos = ref.watch(todayTodoListProvider);
    final todayHabits = ref.watch(habitListProvider);
    final activePreview = ref.watch(activeTodoPreviewProvider);
    final upcomingAnniversaries = ref.watch(upcomingAnniversaryListProvider);
    final recentNotes = ref.watch(recentNoteListProvider);
    final displaySettings = ref.watch(appDisplaySettingsProvider);
    final anniversarySummary = ref.watch(anniversarySummaryProvider);
    final goalSummary = ref.watch(goalSummaryProvider);
    final noteSummary = ref.watch(noteSummaryProvider);
    final isAdmin = ref.watch(currentUserIsAdminProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final dateLabel = '${now.month}月${now.day}日 ${_weekdayLabel(now.weekday)}';
    final settings = displaySettings.maybeWhen(
      data: (value) => value,
      orElse: () => const AppDisplaySettings(),
    );

    // Trigger severe weather notification when weather data arrives.
    ref.listen(currentWeatherProvider, (_, next) {
      next.whenData((info) {
        if (info != null && info.hasSevereAlert) {
          AppNotificationService.instance.showWeatherAlert(info);
        }
      });
    });

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('今日', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '$dateLabel ${_greetingText(now.hour)}',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          if (settings.showWeather) ...<Widget>[
            const WeatherCard(),
            const SizedBox(height: 16),
          ],
          TodayOverviewCard(
            todoSummary: summary,
            scheduleSummary: scheduleSummary,
            habitSummary: habitSummary,
            completionRate: completionRate,
            habitCurrentStreak: habitCurrentStreak,
            pendingReminderCount: pendingReminderCount,
          ),
          const SizedBox(height: 16),
          if (settings.showTodayHero) ...<Widget>[
            _TodayHeroCard(
              summary: summary,
              onOpenTodoPage: () => context.go('/todo'),
            ),
            const SizedBox(height: 16),
          ],
          _DeepLinkSection(
            title: '快捷入口',
            description: '常用功能直达，减少切换成本。',
            items: <_FeatureShortcutItem>[
              _FeatureShortcutItem(
                label: '即将到来',
                subtitle: anniversarySummary.maybeWhen(
                  data: (value) => '30 天内 ${value.upcoming30Days} 个纪念日',
                  orElse: () => '进入纪念日冲刺页',
                ),
                icon: Icons.event_available_outlined,
                color: const Color(0xFFB03A2E),
                onTap: () => context.go('/anniversary/upcoming'),
              ),
              _FeatureShortcutItem(
                label: '日记时间轴',
                subtitle: noteSummary.maybeWhen(
                  data: (value) => '日记 ${value.diaryCount} 条',
                  orElse: () => '按时间回看记录',
                ),
                icon: Icons.menu_book_outlined,
                color: const Color(0xFF5D7A5D),
                onTap: () => context.go('/note/journal'),
              ),
              _FeatureShortcutItem(
                label: isAdmin ? '用户管理' : '账号与同步',
                subtitle: isAdmin ? '切换成员、角色和权限' : '查看当前账号与工作空间',
                icon: isAdmin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.person_outline,
                color: const Color(0xFF37474F),
                onTap: () => context.go('/settings/account'),
              ),
              _FeatureShortcutItem(
                label: '反馈支持',
                subtitle: '随手记录问题、建议和联系方式',
                icon: Icons.support_agent_outlined,
                color: const Color(0xFF136F63),
                onTap: () => context.go('/settings/support'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FeatureShortcutSection(
            title: '全部功能',
            description: '所有模块一览，点击直达。',
            items: <_FeatureShortcutItem>[
              _FeatureShortcutItem(
                label: '日程',
                subtitle: scheduleSummary.maybeWhen(
                  data: (value) => '今天 ${value.today} 项',
                  orElse: () => '查看时间安排',
                ),
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFF136F63),
                onTap: () => context.go('/schedule'),
              ),
              _FeatureShortcutItem(
                label: '待办',
                subtitle: summary.maybeWhen(
                  data: (value) => '今日 ${value.today} 条',
                  orElse: () => '管理任务清单',
                ),
                icon: Icons.checklist_outlined,
                color: const Color(0xFFC06C00),
                onTap: () => context.go('/todo'),
              ),
              _FeatureShortcutItem(
                label: '习惯',
                subtitle: habitSummary.maybeWhen(
                  data: (value) => '已打卡 ${value.checkedToday}',
                  orElse: () => '查看今日打卡',
                ),
                icon: Icons.bolt_outlined,
                color: const Color(0xFF607D8B),
                onTap: () => context.go('/habit'),
              ),
              _FeatureShortcutItem(
                label: '纪念日',
                subtitle: anniversarySummary.maybeWhen(
                  data: (value) => '30 天内 ${value.upcoming30Days} 个',
                  orElse: () => '重要日期提醒',
                ),
                icon: Icons.celebration_outlined,
                color: const Color(0xFFB03A2E),
                onTap: () => context.go('/anniversary'),
              ),
              _FeatureShortcutItem(
                label: '目标',
                subtitle: goalSummary.maybeWhen(
                  data: (value) => '进行中 ${value.active} 个',
                  orElse: () => '查看推进状态',
                ),
                icon: Icons.flag_outlined,
                color: const Color(0xFF8A5CF6),
                onTap: () => context.go('/goal'),
              ),
              _FeatureShortcutItem(
                label: '笔记',
                subtitle: noteSummary.maybeWhen(
                  data: (value) => '收藏 ${value.favorites} 条',
                  orElse: () => '最近想法记录',
                ),
                icon: Icons.note_alt_outlined,
                color: const Color(0xFF5D7A5D),
                onTap: () => context.go('/note'),
              ),
              _FeatureShortcutItem(
                label: '时间线',
                subtitle: '回看最近记录',
                icon: Icons.insights_outlined,
                color: const Color(0xFF114B45),
                onTap: () => context.go('/timeline'),
              ),
              _FeatureShortcutItem(
                label: '设置',
                subtitle: '提醒与工作空间',
                icon: Icons.settings_outlined,
                color: const Color(0xFF37474F),
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '今日日程',
            subtitle: '今天的时间安排，完成后可直接打勾。',
            actionLabel: '进入日程页',
            onAction: () => context.go('/schedule'),
            child: todaySchedules.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptySectionState(
                    title: '今天还没有日程',
                    description: '可以去日程页快速安排今天或明天的时间块。',
                  );
                }

                return Column(
                  children: items
                      .map(
                        (schedule) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TodayScheduleTile(
                            schedule: schedule,
                            isPending: _pendingScheduleIds.contains(
                              schedule.id,
                            ),
                            onChanged: (value) =>
                                _toggleSchedule(schedule, value ?? false),
                            onOpenDetail: () =>
                                context.push('/schedule/${schedule.id}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const _LoadingSection(),
              error: (error, stackTrace) =>
                  _ErrorSection(message: '今日日程加载失败：$error'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '今日习惯',
            subtitle: '今天待打卡的习惯，保持连续记录。',
            actionLabel: '进入习惯页',
            onAction: () => context.go('/habit'),
            child: todayHabits.when(
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptySectionState(
                    title: '今天还没有习惯',
                    description: '可以去习惯页新增一个习惯并设置提醒时间。',
                  );
                }

                return Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TodayHabitTile(
                            item: item,
                            isPending: _pendingHabitIds.contains(item.habit.id),
                            onChanged: (value) =>
                                _toggleHabit(item, value ?? false),
                            onOpenDetail: () =>
                                context.push('/habit/${item.habit.id}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const _LoadingSection(),
              error: (error, stackTrace) =>
                  _ErrorSection(message: '今日习惯加载失败：$error'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '今天要处理的待办',
            subtitle: '截止今天的任务，优先处理。',
            actionLabel: '查看全部待办',
            onAction: () => context.go('/todo'),
            child: todayTodos.when(
              data: (todos) {
                if (todos.isEmpty) {
                  return const _EmptySectionState(
                    title: '今天没有到期待办',
                    description: '可以去待办页补充新的今日任务，或者先处理进行中的事项。',
                  );
                }

                return Column(
                  children: todos
                      .map(
                        (todo) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TodayTodoTile(
                            todo: todo,
                            isPending: _pendingTodoIds.contains(todo.id),
                            onChanged: (value) =>
                                _toggleTodo(todo, value ?? false),
                            onOpenDetail: () =>
                                context.push('/todo/${todo.id}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const _LoadingSection(),
              error: (error, stackTrace) =>
                  _ErrorSection(message: '今日待办加载失败：$error'),
            ),
          ),
          const SizedBox(height: 16),
          if (settings.showUpcomingAnniversaries) ...<Widget>[
            const SizedBox(height: 16),
            _SectionCard(
              title: '临近纪念日',
              subtitle: '展示近期要到来的纪念日，避免遗漏重要时间点。',
              actionLabel: '进入纪念日',
              onAction: () => context.go('/anniversary'),
              child: upcomingAnniversaries.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptySectionState(
                      title: '还没有纪念日',
                      description: '可以先添加几个重要日期，首页会自动提醒。',
                    );
                  }

                  return Column(
                    children: items
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AnniversaryPreviewTile(
                              anniversary: item,
                              onOpenDetail: () =>
                                  context.push('/anniversary/${item.id}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const _LoadingSection(),
                error: (error, stackTrace) =>
                    _ErrorSection(message: '纪念日加载失败：$error'),
              ),
            ),
          ],
          if (settings.showRecentNotes) ...<Widget>[
            const SizedBox(height: 16),
            _SectionCard(
              title: '最近笔记',
              subtitle: '展示最近更新的笔记，方便快速回到思考上下文。',
              actionLabel: '进入笔记',
              onAction: () => context.go('/note'),
              child: recentNotes.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptySectionState(
                      title: '还没有笔记',
                      description: '可以先记录一条想法或复盘，首页会展示最近内容。',
                    );
                  }

                  return Column(
                    children: items
                        .map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _NotePreviewTile(
                              note: note,
                              onOpenDetail: () =>
                                  context.push('/note/${note.id}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const _LoadingSection(),
                error: (error, stackTrace) =>
                    _ErrorSection(message: '最近笔记加载失败：$error'),
              ),
            ),
          ],
          if (settings.showActiveTodoPreview) ...<Widget>[
            const SizedBox(height: 16),
            _SectionCard(
              title: '进行中预览',
              subtitle: '最多展示 5 条正在推进的待办，方便快速回到上下文。',
              actionLabel: '进入待办页',
              onAction: () => context.go('/todo'),
              child: activePreview.when(
                data: (todos) {
                  if (todos.isEmpty) {
                    return const _EmptySectionState(
                      title: '还没有进行中的待办',
                      description: '先去待办页新增一条任务，今天页会自动同步显示。',
                    );
                  }

                  return Column(
                    children: todos
                        .map(
                          (todo) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PreviewTile(
                              todo: todo,
                              onOpenDetail: () =>
                                  context.push('/todo/${todo.id}'),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const _LoadingSection(),
                error: (error, stackTrace) =>
                    _ErrorSection(message: '进行中待办加载失败：$error'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleTodo(TodosTableData todo, bool completed) async {
    if (_pendingTodoIds.contains(todo.id)) {
      return;
    }

    setState(() => _pendingTodoIds.add(todo.id));
    try {
      await ref.read(todoActionsProvider).toggleTodoCompletion(todo, completed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新待办状态失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingTodoIds.remove(todo.id));
      }
    }
  }

  Future<void> _toggleSchedule(
    SchedulesTableData schedule,
    bool completed,
  ) async {
    if (_pendingScheduleIds.contains(schedule.id)) {
      return;
    }

    setState(() => _pendingScheduleIds.add(schedule.id));
    try {
      await ref
          .read(scheduleActionsProvider)
          .toggleScheduleCompletion(schedule, completed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新日程状态失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingScheduleIds.remove(schedule.id));
      }
    }
  }

  Future<void> _toggleHabit(HabitTodayItem item, bool checked) async {
    if (_pendingHabitIds.contains(item.habit.id)) {
      return;
    }

    setState(() => _pendingHabitIds.add(item.habit.id));
    try {
      await ref.read(habitActionsProvider).toggleHabitCheckIn(item, checked);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新习惯状态失败：$error')));
      }
    } finally {
      if (mounted) {
        setState(() => _pendingHabitIds.remove(item.habit.id));
      }
    }
  }

  String _weekdayLabel(int weekday) {
    const labels = <int, String>{
      DateTime.monday: '星期一',
      DateTime.tuesday: '星期二',
      DateTime.wednesday: '星期三',
      DateTime.thursday: '星期四',
      DateTime.friday: '星期五',
      DateTime.saturday: '星期六',
      DateTime.sunday: '星期日',
    };
    return labels[weekday] ?? '';
  }

  String _greetingText(int hour) {
    if (hour < 6) {
      return '夜深了，注意休息。';
    } else if (hour < 9) {
      return '早上好，新的一天开始了。';
    } else if (hour < 12) {
      return '上午好，专注处理今天的事。';
    } else if (hour < 14) {
      return '中午好，记得休息一下。';
    } else if (hour < 18) {
      return '下午好，继续保持节奏。';
    } else if (hour < 22) {
      return '晚上好，今天完成得怎么样？';
    } else {
      return '快去休息吧，明天继续。';
    }
  }
}

class _TodayHeroCard extends StatelessWidget {
  const _TodayHeroCard({required this.summary, required this.onOpenTodoPage});

  final AsyncValue<TodoSummary> summary;
  final VoidCallback onOpenTodoPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: const Color(0xFF114B45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '今天先把高价值事项做完',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '专注当下，把今天最重要的事做完。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
              ),
            ),
            const SizedBox(height: 18),
            summary.when(
              data: (value) => Row(
                children: <Widget>[
                  Expanded(
                    child: _HeroMetric(
                      label: '今日待办',
                      value: value.today.toString(),
                    ),
                  ),
                  Expanded(
                    child: _HeroMetric(
                      label: '进行中',
                      value: value.active.toString(),
                    ),
                  ),
                  Expanded(
                    child: _HeroMetric(
                      label: '已完成',
                      value: value.completed.toString(),
                    ),
                  ),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
              error: (error, stackTrace) => Text(
                '统计加载失败：$error',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: onOpenTodoPage,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('进入待办页'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF114B45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle),
                    ],
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DeepLinkSection extends StatelessWidget {
  const _DeepLinkSection({
    required this.title,
    required this.description,
    required this.items,
  });

  final String title;
  final String description;
  final List<_FeatureShortcutItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F0E5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 760 ? 4 : 2;
                final itemWidth = (width - (columns - 1) * 10) / columns;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: itemWidth,
                          child: _FeatureShortcutCard(item: item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureShortcutSection extends StatelessWidget {
  const _FeatureShortcutSection({
    required this.title,
    required this.description,
    required this.items,
  });

  final String title;
  final String description;
  final List<_FeatureShortcutItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('全部功能', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '把各模块入口固定在首页，减少来回切换成本。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 760 ? 4 : 2;
                final itemWidth = (width - (columns - 1) * 10) / columns;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: items
                      .map(
                        (item) => SizedBox(
                          width: itemWidth,
                          child: _FeatureShortcutCard(item: item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureShortcutItem {
  const _FeatureShortcutItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _FeatureShortcutCard extends StatelessWidget {
  const _FeatureShortcutCard({required this.item});

  final _FeatureShortcutItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: item.onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: item.color.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(item.icon, color: item.color),
            const SizedBox(height: 12),
            Text(
              item.label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(item.subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _TodayScheduleTile extends StatelessWidget {
  const _TodayScheduleTile({
    required this.schedule,
    required this.isPending,
    required this.onChanged,
    required this.onOpenDetail,
  });

  final SchedulesTableData schedule;
  final bool isPending;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final start = DateFormat('HH:mm').format(schedule.startAt.toLocal());
    final end = DateFormat('HH:mm').format(schedule.endAt.toLocal());

    return Material(
      color: const Color(0xFFF8F6F1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: schedule.status == 'completed',
                onChanged: isPending ? null : onChanged,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      schedule.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _InlineTag(
                          label: '$start - $end',
                          color: const Color(0xFF136F63),
                        ),
                        _InlineTag(
                          label: schedule.status == 'completed' ? '已完成' : '待进行',
                          color: schedule.status == 'completed'
                              ? const Color(0xFF607D8B)
                              : const Color(0xFFC06C00),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayHabitTile extends StatelessWidget {
  const _TodayHabitTile({
    required this.item,
    required this.isPending,
    required this.onChanged,
    required this.onOpenDetail,
  });

  final HabitTodayItem item;
  final bool isPending;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final isPaused = item.habit.status == 'paused';
    return Material(
      color: const Color(0xFFF8F6F1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: item.checkedToday,
                onChanged: isPending || isPaused ? null : onChanged,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.habit.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _InlineTag(
                          label: item.checkedToday ? '今天已打卡' : '今天未打卡',
                          color: item.checkedToday
                              ? const Color(0xFF136F63)
                              : const Color(0xFFC06C00),
                        ),
                        if (item.habit.reminderTime != null)
                          _InlineTag(
                            label: '提醒 ${item.habit.reminderTime}',
                            color: const Color(0xFF607D8B),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTodoTile extends StatelessWidget {
  const _TodayTodoTile({
    required this.todo,
    required this.isPending,
    required this.onChanged,
    required this.onOpenDetail,
  });

  final TodosTableData todo;
  final bool isPending;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final dueAt = todo.dueAt?.toLocal();

    return Material(
      color: const Color(0xFFF8F6F1),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Checkbox(
                value: todo.status == 'completed',
                onChanged: isPending ? null : onChanged,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      todo.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _InlineTag(
                          label: _priorityLabel(todo.priority),
                          color: _priorityColor(todo.priority),
                        ),
                        if (dueAt != null)
                          _InlineTag(
                            label: '截止 ${DateFormat('HH:mm').format(dueAt)}',
                            color: const Color(0xFFC06C00),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _priorityLabel(String value) {
    return TodoPriority.fromValue(value).label;
  }

  Color _priorityColor(String value) {
    switch (TodoPriority.fromValue(value)) {
      case TodoPriority.urgentImportant:
        return const Color(0xFFB03A2E);
      case TodoPriority.notUrgentImportant:
        return const Color(0xFF2874A6);
      case TodoPriority.urgentNotImportant:
        return const Color(0xFFC06C00);
      case TodoPriority.notUrgentNotImportant:
        return const Color(0xFF5D7A5D);
    }
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.todo, required this.onOpenDetail});

  final TodosTableData todo;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpenDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _priorityColor(todo.priority),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                todo.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (todo.dueAt != null)
              Text(
                DateFormat('M月d日').format(todo.dueAt!.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String value) {
    switch (TodoPriority.fromValue(value)) {
      case TodoPriority.urgentImportant:
        return const Color(0xFFB03A2E);
      case TodoPriority.notUrgentImportant:
        return const Color(0xFF2874A6);
      case TodoPriority.urgentNotImportant:
        return const Color(0xFFC06C00);
      case TodoPriority.notUrgentNotImportant:
        return const Color(0xFF5D7A5D);
    }
  }
}

class _AnniversaryPreviewTile extends StatelessWidget {
  const _AnniversaryPreviewTile({
    required this.anniversary,
    required this.onOpenDetail,
  });

  final AnniversariesTableData anniversary;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final days = daysUntilNextAnniversary(anniversary.baseDate);
    final label = days == 0 ? '今天' : '$days 天后';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpenDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          children: <Widget>[
            const Icon(Icons.celebration_outlined, color: Color(0xFFB03A2E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                anniversary.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NotePreviewTile extends StatelessWidget {
  const _NotePreviewTile({required this.note, required this.onOpenDetail});

  final NotesTableData note;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final title = (note.title == null || note.title!.trim().isEmpty)
        ? '无标题笔记'
        : note.title!;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpenDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.note_alt_outlined, color: Color(0xFF5D7A5D)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    note.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  const _InlineTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(
          Icons.inbox_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center),
      ],
    );
  }
}

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorSection extends StatelessWidget {
  const _ErrorSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message);
  }
}
