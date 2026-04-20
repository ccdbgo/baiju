import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserPage extends ConsumerWidget {
  const UserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentUserWorkspaceProvider);
    final activeUser = ref.watch(activeUserProfileProvider);
    final isAdmin = ref.watch(currentUserIsAdminProvider);
    final preferences = ref.watch(userPreferencesProvider);
    final users = ref.watch(userListProvider);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          Text('用户管理', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '每个用户的数据独立隔离，切换用户需要验证密码。',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          // 当前用户卡
          activeUser.when(
            data: (user) => _CurrentUserCard(user: user, workspaceId: workspace.userId),
            loading: () => const _SectionCard(
              title: '当前用户',
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _SectionCard(title: '当前用户', child: Text('加载失败：$e')),
          ),
          const SizedBox(height: 16),
          // 用户列表（所有人可见，但操作受权限控制）
          _SectionCard(
            title: '用户列表',
            child: users.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Text('暂无用户。');
                }
                return Column(
                  children: items.map((user) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _UserListTile(
                        user: user,
                        isActive: user.id == workspace.userId,
                        isAdmin: isAdmin,
                        onSwitch: () => _switchUser(context, ref, user),
                        onEditRole: isAdmin
                            ? () => _editRole(context, ref, user)
                            : null,
                        onResetPassword: isAdmin
                            ? () => _resetPassword(context, ref, user)
                            : null,
                        onDelete: isAdmin
                            ? () => _deleteUser(context, ref, user)
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('用户列表加载失败：$e'),
            ),
          ),
          const SizedBox(height: 16),
          // 管理员操作区
          if (isAdmin) ...<Widget>[
            _SectionCard(
              title: '管理员操作',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => _createUser(context, ref),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('新建用户'),
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
          ],
          // 用户偏好设置
          _SectionCard(
            title: '当前用户规则',
            child: preferences.when(
              data: (value) => _UserPreferencePanel(
                preferences: value,
                onAutoRolloverChanged: (enabled) => _savePreferences(
                  context, ref,
                  value.copyWith(autoRolloverTodosToToday: enabled),
                  '已更新待办顺延规则',
                ),
                onReminderChanged: (minutes) => _savePreferences(
                  context, ref,
                  minutes == null
                      ? value.copyWith(clearDefaultScheduleReminder: true)
                      : value.copyWith(defaultScheduleReminderMinutes: minutes),
                  '已更新默认提醒',
                ),
                onAutoSyncChanged: (enabled) => _savePreferences(
                  context, ref,
                  value.copyWith(autoSyncOnLaunch: enabled),
                  '已更新同步策略',
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('用户规则加载失败：$e'),
            ),
          ),
        ],
      ),
    );
  }

  // --- 切换用户（需密码验证）---
  Future<void> _switchUser(
    BuildContext context,
    WidgetRef ref,
    UsersTableData user,
  ) async {
    final actions = ref.read(userActionsProvider);
    final hasPassword = await actions.userHasPassword(user.id);

    if (hasPassword) {
      if (!context.mounted) return;
      final password = await _showPasswordDialog(
        context,
        title: '切换到 ${user.displayName}',
        hint: '请输入该用户的密码',
      );
      if (password == null) return;
      final ok = await actions.verifyUserPassword(user.id, password);
      if (!ok) {
        if (context.mounted) {
          _showSnack(context, '密码错误，切换失败');
        }
        return;
      }
    }

    try {
      await actions.switchUser(user.id);
      if (context.mounted) _showSnack(context, '已切换到 ${user.displayName}');
    } catch (e) {
      if (context.mounted) _showSnack(context, '切换失败：$e');
    }
  }

  // --- 新建用户 ---
  Future<void> _createUser(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CreateUserResult>(
      context: context,
      builder: (ctx) => const _CreateUserDialog(),
    );
    if (result == null) return;

    try {
      await ref.read(userActionsProvider).createLocalUser(
        result.displayName,
        password: result.password.isNotEmpty ? result.password : null,
      );
      if (context.mounted) _showSnack(context, '已创建并切换到 ${result.displayName}');
    } catch (e) {
      if (context.mounted) _showSnack(context, '创建失败：$e');
    }
  }

  // --- 修改角色 ---
  Future<void> _editRole(
    BuildContext context,
    WidgetRef ref,
    UsersTableData user,
  ) async {
    final current = UserRole.fromValue(user.role);
    final newRole = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => _RoleDialog(current: current, userName: user.displayName),
    );
    if (newRole == null || newRole == current) return;

    try {
      await ref.read(userActionsProvider).updateUserRole(
        userId: user.id,
        role: newRole,
      );
      if (context.mounted) _showSnack(context, '已将 ${user.displayName} 设为 ${newRole.label}');
    } catch (e) {
      if (context.mounted) _showSnack(context, '修改失败：$e');
    }
  }

  // --- 重置密码 ---
  Future<void> _resetPassword(
    BuildContext context,
    WidgetRef ref,
    UsersTableData user,
  ) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => _ResetPasswordDialog(userName: user.displayName),
    );
    if (result == null) return; // cancelled

    try {
      if (result.isEmpty) {
        await ref.read(userActionsProvider).clearUserPassword(user.id);
        if (context.mounted) _showSnack(context, '已清除 ${user.displayName} 的密码');
      } else {
        await ref.read(userActionsProvider).setUserPassword(user.id, result);
        if (context.mounted) _showSnack(context, '已重置 ${user.displayName} 的密码');
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, '操作失败：$e');
    }
  }

  // --- 删除用户 ---
  Future<void> _deleteUser(
    BuildContext context,
    WidgetRef ref,
    UsersTableData user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('确定要删除用户「${user.displayName}」吗？该用户的所有数据将被软删除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(userActionsProvider).deleteUser(user.id);
      if (context.mounted) _showSnack(context, '已删除用户 ${user.displayName}');
    } catch (e) {
      if (context.mounted) _showSnack(context, '删除失败：$e');
    }
  }

  Future<void> _signInWithWechat(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(userActionsProvider).signInWithWechat();
      if (context.mounted) _showSnack(context, '微信身份已绑定');
    } catch (e) {
      if (context.mounted) _showSnack(context, '绑定失败：$e');
    }
  }

  Future<void> _signOutToLocal(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(userActionsProvider).signOutToLocal();
      if (context.mounted) _showSnack(context, '已切回默认用户');
    } catch (e) {
      if (context.mounted) _showSnack(context, '操作失败：$e');
    }
  }

  Future<void> _savePreferences(
    BuildContext context,
    WidgetRef ref,
    UserPreferences preferences,
    String message,
  ) async {
    await ref.read(userPreferenceActionsProvider).save(preferences);
    if (context.mounted) _showSnack(context, message);
  }

  Future<String?> _showPasswordDialog(
    BuildContext context, {
    required String title,
    required String hint,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(labelText: hint),
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
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ---------------------------------------------------------------------------
// 当前用户卡
// ---------------------------------------------------------------------------

class _CurrentUserCard extends StatelessWidget {
  const _CurrentUserCard({required this.user, required this.workspaceId});

  final UsersTableData? user;
  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    final role = UserRole.fromValue(user?.role ?? UserRole.member.value);
    final provider = AppUserAuthProvider.fromValue(
      user?.authProvider ?? AppUserAuthProvider.local.value,
    );
    return _SectionCard(
      title: '当前用户',
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            child: Text(
              (user?.displayName ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user?.displayName ?? '默认用户',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _RoleChip(role: role),
                    Chip(label: Text(provider.label)),
                    if (user?.wechatUnionId != null)
                      const Chip(label: Text('已绑定微信')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 用户列表项
// ---------------------------------------------------------------------------

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.isActive,
    required this.isAdmin,
    required this.onSwitch,
    this.onEditRole,
    this.onResetPassword,
    this.onDelete,
  });

  final UsersTableData user;
  final bool isActive;
  final bool isAdmin;
  final VoidCallback onSwitch;
  final VoidCallback? onEditRole;
  final VoidCallback? onResetPassword;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final role = UserRole.fromValue(user.role);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: isActive ? colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 20,
              backgroundColor: isActive
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHighest,
              foregroundColor: isActive
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
              child: Text(
                user.displayName.substring(0, 1).toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  _RoleChip(role: role, small: true),
                ],
              ),
            ),
            if (isActive)
              const Icon(Icons.check_circle)
            else
              TextButton(
                onPressed: onSwitch,
                child: const Text('切换'),
              ),
            if (isAdmin && !isActive) ...<Widget>[
              PopupMenuButton<_UserAction>(
                onSelected: (action) {
                  switch (action) {
                    case _UserAction.editRole:
                      onEditRole?.call();
                    case _UserAction.resetPassword:
                      onResetPassword?.call();
                    case _UserAction.delete:
                      onDelete?.call();
                  }
                },
                itemBuilder: (ctx) => <PopupMenuEntry<_UserAction>>[
                  const PopupMenuItem(
                    value: _UserAction.editRole,
                    child: ListTile(
                      leading: Icon(Icons.manage_accounts_outlined),
                      title: Text('修改角色'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: _UserAction.resetPassword,
                    child: ListTile(
                      leading: Icon(Icons.lock_reset_outlined),
                      title: Text('重置密码'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: _UserAction.delete,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: Theme.of(ctx).colorScheme.error,
                      ),
                      title: Text(
                        '删除用户',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _UserAction { editRole, resetPassword, delete }

// ---------------------------------------------------------------------------
// 角色标签
// ---------------------------------------------------------------------------

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, this.small = false});

  final UserRole role;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(
        role.label,
        style: TextStyle(
          fontSize: small ? 11 : null,
          color: isAdmin ? colorScheme.onPrimary : null,
        ),
      ),
      backgroundColor: isAdmin ? colorScheme.primary : null,
      padding: small ? EdgeInsets.zero : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ---------------------------------------------------------------------------
// 新建用户对话框
// ---------------------------------------------------------------------------

class _CreateUserResult {
  const _CreateUserResult({required this.displayName, required this.password});
  final String displayName;
  final String password;
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog();

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建用户'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '例如：学习账号',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '密码（可选）',
              hintText: '留空则无需密码',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: '确认密码'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('创建'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.isNotEmpty && password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次密码不一致')),
      );
      return;
    }
    Navigator.of(context).pop(
      _CreateUserResult(displayName: name, password: password),
    );
  }
}

// ---------------------------------------------------------------------------
// 修改角色对话框
// ---------------------------------------------------------------------------

class _RoleDialog extends StatefulWidget {
  const _RoleDialog({required this.current, required this.userName});

  final UserRole current;
  final String userName;

  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late UserRole _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('修改 ${widget.userName} 的角色'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: UserRole.values.map((role) {
          return RadioListTile<UserRole>(
            title: Text(role.label),
            value: role,
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v!),
          );
        }).toList(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('确认'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 重置密码对话框
// ---------------------------------------------------------------------------

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.userName});

  final String userName;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('重置 ${widget.userName} 的密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _controller,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '新密码（留空则清除密码）',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: '确认新密码'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('确认'),
        ),
      ],
    );
  }

  void _submit() {
    final password = _controller.text;
    final confirm = _confirmController.text;
    if (password.isNotEmpty && password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次密码不一致')),
      );
      return;
    }
    Navigator.of(context).pop(password); // empty string = clear password
  }
}

// ---------------------------------------------------------------------------
// 通用 Section 卡片
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// 用户偏好面板
// ---------------------------------------------------------------------------

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
