import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/features/settings/domain/app_display_settings.dart';
import 'package:baiju_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isManagingReminders = false;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(currentUserWorkspaceProvider);
    final activeUser = ref.watch(activeUserProfileProvider);
    final currentUserRole = ref.watch(currentUserRoleProvider);
    final isAdmin = ref.watch(currentUserIsAdminProvider);
    final preferences = ref.watch(userPreferencesProvider);
    final displaySettings = ref.watch(appDisplaySettingsProvider);
    final users = ref.watch(userListProvider);
    final pendingSyncCount = ref.watch(pendingUserSyncCountProvider);
    final pendingReminderCount = ref.watch(pendingReminderCountProvider);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('设置', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '这里统一管理工作空间、提醒、首页显示策略和应用信息。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: '当前摘要',
            child: _SettingsOverviewCard(
              userLabel: activeUser.maybeWhen(
                data: (user) =>
                    '${user?.displayName ?? '默认用户'} · ${UserRole.fromValue(user?.role ?? UserRole.member.value).label}',
                orElse: () => '加载中',
              ),
              syncCount: pendingSyncCount.maybeWhen(
                data: (count) => count,
                orElse: () => null,
              ),
              reminderCount: pendingReminderCount.maybeWhen(
                data: (count) => count,
                orElse: () => null,
              ),
              userCount: users.maybeWhen(
                data: (items) => items.length,
                orElse: () => null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '设置分区',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _EntryCard(
                  title: '账号与同步',
                  subtitle: isAdmin ? '切换工作空间、查看同步状态' : '管理员专用',
                  icon: Icons.manage_accounts_outlined,
                  onTap: isAdmin
                      ? () => context.push('/settings/account')
                      : null,
                ),
                _EntryCard(
                  title: '通知与提醒',
                  subtitle: '同步本地提醒和提醒偏好',
                  icon: Icons.notifications_active_outlined,
                  onTap: () => context.push('/settings/notifications'),
                ),
                _EntryCard(
                  title: '通用设置',
                  subtitle: '首页显示与应用行为开关',
                  icon: Icons.tune_outlined,
                  onTap: () => context.push('/settings/general'),
                ),
                _EntryCard(
                  title: '关于',
                  subtitle: '产品说明、状态和支持信息',
                  icon: Icons.info_outline,
                  onTap: () => context.push('/settings/about'),
                ),
                _EntryCard(
                  title: '赞助与支持',
                  subtitle: '预留赞助、反馈与版本计划入口',
                  icon: Icons.favorite_border,
                  onTap: () => context.push('/settings/support'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '常用入口',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                SizedBox(
                  width: 170,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/account'),
                    icon: Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                    ),
                    label: Text(isAdmin ? '用户管理' : '账号与同步'),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/notifications'),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      pendingReminderCount.maybeWhen(
                        data: (count) => '提醒 $count',
                        orElse: () => '提醒中心',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/general'),
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('首页显示'),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('/settings/support'),
                    icon: const Icon(Icons.support_agent_outlined),
                    label: const Text('反馈支持'),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/settings/about'),
                    icon: const Icon(Icons.info_outline),
                    label: Text(
                      pendingSyncCount.maybeWhen(
                        data: (count) => '同步队列 $count',
                        orElse: () => '关于应用',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          activeUser.when(
            data: (user) {
              final provider = AppUserAuthProvider.fromValue(
                user?.authProvider ?? AppUserAuthProvider.local.value,
              );
              return _SectionCard(
                title: '当前工作空间',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user?.displayName ?? '默认用户',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        Chip(label: Text(provider.label)),
                        Chip(label: Text(currentUserRole.label)),
                        Chip(label: Text('user_id ${workspace.userId}')),
                        Chip(label: Text('device ${workspace.deviceId}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    pendingSyncCount.when(
                      data: (count) => Text('待同步队列：$count'),
                      loading: () => const Text('正在读取同步状态...'),
                      error: (error, stackTrace) => Text('同步状态读取失败：$error'),
                    ),
                  ],
                ),
              );
            },
            loading: () => const _SectionCard(
              title: '当前工作空间',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                _SectionCard(title: '当前工作空间', child: Text('用户信息加载失败：$error')),
          ),
          const SizedBox(height: 16),
          if (isAdmin) ...<Widget>[
            _SectionCard(
              title: '账号动作',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => _createLocalUser(context, ref),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('新建本地用户'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _signInWithWechat(context, ref),
                    icon: const Icon(Icons.wechat),
                    label: const Text('微信一键登录'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _signOutToLocal(context, ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('切回默认用户'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...<Widget>[
            const _SectionCard(
              title: '账号动作',
              child: Text('当前账号不是管理员。普通用户只能使用程序，不能进行用户管理。'),
            ),
            const SizedBox(height: 16),
          ],
          _SectionCard(
            title: '首页显示',
            child: displaySettings.when(
              data: (value) => _DisplaySettingsPanel(
                settings: value,
                onChanged: (next) => _saveDisplaySettings(context, ref, next),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('显示设置加载失败：$error'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '当前用户规则',
            child: preferences.when(
              data: (value) => _UserPreferencePanel(
                preferences: value,
                onAutoRolloverChanged: (enabled) => _savePreferences(
                  context,
                  ref,
                  value.copyWith(autoRolloverTodosToToday: enabled),
                  '已更新待办顺延规则',
                ),
                onReminderChanged: (minutes) => _savePreferences(
                  context,
                  ref,
                  minutes == null
                      ? value.copyWith(clearDefaultScheduleReminder: true)
                      : value.copyWith(defaultScheduleReminderMinutes: minutes),
                  '已更新默认提醒',
                ),
                onAutoSyncChanged: (enabled) => _savePreferences(
                  context,
                  ref,
                  value.copyWith(autoSyncOnLaunch: enabled),
                  '已更新同步策略',
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('用户规则加载失败：$error'),
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '通知与提醒',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                pendingReminderCount.when(
                  data: (count) => Text('当前待触发提醒：$count'),
                  loading: () => const Text('正在读取提醒状态...'),
                  error: (error, stackTrace) => Text('提醒状态读取失败：$error'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _isManagingReminders
                          ? null
                          : () => _syncAllReminders(context, ref),
                      icon: _isManagingReminders
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: const Text('重新同步提醒'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isManagingReminders
                          ? null
                          : () => _clearAllReminders(context, ref),
                      icon: const Icon(Icons.notifications_off_outlined),
                      label: const Text('清空提醒'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isAdmin) ...<Widget>[
            _SectionCard(
              title: '本地用户列表',
              child: users.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Text('当前还没有可切换的用户。');
                  }

                  return Column(
                    children: items
                        .map(
                          (user) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _UserListTile(
                              user: user,
                              isActive: user.id == workspace.userId,
                              onTap: () => _switchUser(context, ref, user.id),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text('用户列表加载失败：$error'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const _SectionCard(
            title: '关于与赞助',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('白驹是一款本地优先的个人时间管理应用，整合日程、待办、习惯、纪念日、目标、笔记和时间线。'),
                SizedBox(height: 8),
                Text('如果白驹对你有帮助，欢迎通过赞助页支持我们继续开发。'),
                SizedBox(height: 8),
                Text('当前版本：V1.0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createLocalUser(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: const Text('新建本地用户'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        hintText: '例如：学习账号 / 工作账号',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '密码（可选）',
                        hintText: '留空则无需密码',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '确认密码'),
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('创建并切换'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmed != true || nameController.text.trim().isEmpty) {
        return;
      }

      final password = passwordController.text;
      final confirm = confirmController.text;
      if (password.isNotEmpty && password != confirm) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('两次密码不一致')),
          );
        }
        return;
      }

      await ref.read(userActionsProvider).createLocalUser(
        nameController.text.trim(),
        password: password.isNotEmpty ? password : null,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已切换到 ${nameController.text.trim()}')),
        );
      }
    } finally {
      nameController.dispose();
      passwordController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _switchUser(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final actions = ref.read(userActionsProvider);
    final hasPassword = await actions.userHasPassword(userId);

    if (hasPassword) {
      if (!context.mounted) return;
      final controller = TextEditingController();
      final password = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('切换用户'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: '请输入该用户的密码'),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('确认'),
            ),
          ],
        ),
      ).whenComplete(controller.dispose);

      if (password == null) return;
      final ok = await actions.verifyUserPassword(userId, password);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('密码错误，切换失败')),
          );
        }
        return;
      }
    }

    await actions.switchUser(userId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('工作空间已切换')));
    }
  }

  Future<void> _signInWithWechat(BuildContext context, WidgetRef ref) async {
    await ref.read(userActionsProvider).signInWithWechat();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('微信身份已绑定并切换到对应工作空间')));
    }
  }

  Future<void> _signOutToLocal(BuildContext context, WidgetRef ref) async {
    await ref.read(userActionsProvider).signOutToLocal();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已切回默认本地用户')));
    }
  }

  Future<void> _savePreferences(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
    String message,
  ) async {
    await ref.read(userPreferenceActionsProvider).save(preferences);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _saveDisplaySettings(
    BuildContext context,
    WidgetRef ref,
    AppDisplaySettings settings,
  ) async {
    await ref.read(appSettingsActionsProvider).save(settings);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('首页显示设置已更新')));
    }
  }

  Future<void> _syncAllReminders(BuildContext context, WidgetRef ref) async {
    setState(() => _isManagingReminders = true);
    try {
      await ref.read(reminderSyncControllerProvider).syncAll();
      ref.invalidate(pendingReminderCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已重新同步本地提醒')));
      }
    } finally {
      if (mounted) {
        setState(() => _isManagingReminders = false);
      }
    }
  }

  Future<void> _clearAllReminders(BuildContext context, WidgetRef ref) async {
    setState(() => _isManagingReminders = true);
    try {
      await ref.read(reminderSyncControllerProvider).clearAll();
      ref.invalidate(pendingReminderCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清空本地提醒')));
      }
    } finally {
      if (mounted) {
        setState(() => _isManagingReminders = false);
      }
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsOverviewCard extends StatelessWidget {
  const _SettingsOverviewCard({
    required this.userLabel,
    required this.syncCount,
    required this.reminderCount,
    required this.userCount,
  });

  final String userLabel;
  final int? syncCount;
  final int? reminderCount;
  final int? userCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _OverviewChip(
          label: '当前用户',
          value: userLabel,
          color: const Color(0xFF136F63),
        ),
        _OverviewChip(
          label: '待同步',
          value: syncCount?.toString() ?? '...',
          color: const Color(0xFFC06C00),
        ),
        _OverviewChip(
          label: '待提醒',
          value: reminderCount?.toString() ?? '...',
          color: const Color(0xFF607D8B),
        ),
        _OverviewChip(
          label: '工作空间',
          value: userCount?.toString() ?? '...',
          color: const Color(0xFF8A5CF6),
        ),
      ],
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Card(
          color: onTap == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisplaySettingsPanel extends StatelessWidget {
  const _DisplaySettingsPanel({
    required this.settings,
    required this.onChanged,
  });

  final AppDisplaySettings settings;
  final ValueChanged<AppDisplaySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SwitchListTile(
          value: settings.showTodayHero,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示今日首页头图'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showTodayHero: value)),
        ),
        SwitchListTile(
          value: settings.showActiveTodoPreview,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示进行中待办预览'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showActiveTodoPreview: value)),
        ),
        SwitchListTile(
          value: settings.showUpcomingAnniversaries,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示临近纪念日'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showUpcomingAnniversaries: value)),
        ),
        SwitchListTile(
          value: settings.showRecentNotes,
          contentPadding: EdgeInsets.zero,
          title: const Text('显示最近笔记'),
          onChanged: (value) =>
              onChanged(settings.copyWith(showRecentNotes: value)),
        ),
      ],
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.isActive,
    required this.onTap,
  });

  final UsersTableData user;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final provider = AppUserAuthProvider.fromValue(user.authProvider);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isActive ? null : onTap,
      child: Card(
        color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text('user_id ${user.id}'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        Chip(label: Text(provider.label)),
                        if (user.wechatUnionId != null)
                          const Chip(label: Text('已绑定微信')),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle)
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserPreferencePanel extends StatelessWidget {
  const _UserPreferencePanel({
    required this.preferences,
    required this.onAutoRolloverChanged,
    required this.onReminderChanged,
    required this.onAutoSyncChanged,
  });

  final UserPreferences preferences;
  final ValueChanged<bool> onAutoRolloverChanged;
  final ValueChanged<int?> onReminderChanged;
  final ValueChanged<bool> onAutoSyncChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          value: preferences.autoRolloverTodosToToday,
          contentPadding: EdgeInsets.zero,
          title: const Text('未完成待办自动顺延到今天'),
          subtitle: const Text('启动应用或切换到该用户时，会把过期待办自动带到今天。'),
          onChanged: onAutoRolloverChanged,
        ),
        const SizedBox(height: 8),
        Text('默认日程提醒', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _PreferenceChip(
              label: '不提醒',
              selected: preferences.defaultScheduleReminderMinutes == null,
              onSelected: () => onReminderChanged(null),
            ),
            _PreferenceChip(
              label: '5 分钟',
              selected: preferences.defaultScheduleReminderMinutes == 5,
              onSelected: () => onReminderChanged(5),
            ),
            _PreferenceChip(
              label: '15 分钟',
              selected: preferences.defaultScheduleReminderMinutes == 15,
              onSelected: () => onReminderChanged(15),
            ),
            _PreferenceChip(
              label: '30 分钟',
              selected: preferences.defaultScheduleReminderMinutes == 30,
              onSelected: () => onReminderChanged(30),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: preferences.autoSyncOnLaunch,
          contentPadding: EdgeInsets.zero,
          title: const Text('启动时自动准备同步'),
          subtitle: const Text('启动时同步本地数据状态，保持多端一致。'),
          onChanged: onAutoSyncChanged,
        ),
      ],
    );
  }
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
