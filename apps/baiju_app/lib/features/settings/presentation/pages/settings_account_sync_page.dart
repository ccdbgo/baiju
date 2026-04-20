import 'package:baiju_app/core/database/app_database.dart';
import 'package:baiju_app/core/sync/sync_engine.dart';
import 'package:baiju_app/core/sync/sync_providers.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserManagementFilter {
  all('全部'),
  admins('管理员'),
  members('普通用户');

  const UserManagementFilter(this.label);

  final String label;
}

class SettingsAccountSyncPage extends ConsumerStatefulWidget {
  const SettingsAccountSyncPage({super.key});

  @override
  ConsumerState<SettingsAccountSyncPage> createState() =>
      _SettingsAccountSyncPageState();
}

class _SettingsAccountSyncPageState
    extends ConsumerState<SettingsAccountSyncPage> {
  final TextEditingController _searchController = TextEditingController();
  UserManagementFilter _filter = UserManagementFilter.all;
  final Set<String> _selectedUserIds = <String>{};
  bool _isSyncing = false;
  SyncResult? _lastSyncResult;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(currentUserWorkspaceProvider);
    final activeUser = ref.watch(activeUserProfileProvider);
    final isAdmin = ref.watch(currentUserIsAdminProvider);
    final users = ref.watch(userListProvider);
    final pendingSyncCount = ref.watch(pendingUserSyncCountProvider);
    final pendingQueueCount = ref.watch(pendingSyncQueueCountProvider);
    final failedItems = ref.watch(failedSyncQueueItemsProvider);
    final syncEngine = ref.watch(syncEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('账号与同步')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: <Widget>[
          if (!isAdmin)
            const _SectionCard(
              title: '访问受限',
              child: Text('只有管理员用户才能进行用户管理。普通用户只能使用程序。'),
            )
          else
            activeUser.when(
              data: (user) {
                final provider = AppUserAuthProvider.fromValue(
                  user?.authProvider ?? AppUserAuthProvider.local.value,
                );
                final role = UserRole.fromValue(
                  user?.role ?? UserRole.member.value,
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
                          Chip(label: Text(role.label)),
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
          if (isAdmin) ...<Widget>[
            const SizedBox(height: 16),
            _SyncCard(
              isConfigured: syncEngine.isConfigured,
              pendingCount: pendingQueueCount,
              failedItems: failedItems,
              isSyncing: _isSyncing,
              lastResult: _lastSyncResult,
              onSync: () => _runSync(context, ref),
            ),
            const SizedBox(height: 16),
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
            _SectionCard(
              title: '用户管理台',
              child: users.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Text('当前还没有可切换的用户。');
                  }

                  final normalizedSearch = _searchController.text
                      .trim()
                      .toLowerCase();
                  final filtered = items.where((user) {
                    final matchesRole = switch (_filter) {
                      UserManagementFilter.all => true,
                      UserManagementFilter.admins =>
                        user.role == UserRole.admin.value,
                      UserManagementFilter.members =>
                        user.role == UserRole.member.value,
                    };
                    if (!matchesRole) {
                      return false;
                    }
                    if (normalizedSearch.isEmpty) {
                      return true;
                    }
                    return user.displayName.toLowerCase().contains(
                          normalizedSearch,
                        ) ||
                        user.id.toLowerCase().contains(normalizedSearch);
                  }).toList();

                  final adminCount = items
                      .where((user) => user.role == UserRole.admin.value)
                      .length;
                  final memberCount = items
                      .where((user) => user.role == UserRole.member.value)
                      .length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _UserManagementSummary(
                        total: items.length,
                        admins: adminCount,
                        members: memberCount,
                      ),
                      if (_selectedUserIds.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 12),
                        _BulkActionBar(
                          selectedCount: _selectedUserIds.length,
                          onPromote: () =>
                              _bulkUpdateRole(context, ref, UserRole.admin),
                          onDemote: () =>
                              _bulkUpdateRole(context, ref, UserRole.member),
                          onDelete: () => _bulkDeleteUsers(context, ref),
                          onClear: () =>
                              setState(() => _selectedUserIds.clear()),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '搜索用户',
                          hintText: '按用户名或 user_id 搜索',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: UserManagementFilter.values.map((item) {
                          return ChoiceChip(
                            label: Text(item.label),
                            selected: item == _filter,
                            onSelected: (_) => setState(() => _filter = item),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        const Text('当前筛选条件下没有用户。')
                      else
                        Column(
                          children: filtered
                              .map(
                                (user) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _UserListTile(
                                    user: user,
                                    isActive: user.id == workspace.userId,
                                    isCurrentAdmin: isAdmin,
                                    isSelected: _selectedUserIds.contains(
                                      user.id,
                                    ),
                                    onTap: () =>
                                        _switchUser(context, ref, user.id),
                                    onSelectionChanged:
                                        user.id == workspace.userId
                                        ? null
                                        : (selected) => setState(() {
                                            if (selected) {
                                              _selectedUserIds.add(user.id);
                                            } else {
                                              _selectedUserIds.remove(user.id);
                                            }
                                          }),
                                    onRoleChanged: user.id == workspace.userId
                                        ? null
                                        : (role) => _updateRole(
                                            context,
                                            ref,
                                            user.id,
                                            role,
                                          ),
                                    onDelete: user.id == workspace.userId
                                        ? null
                                        : () => _deleteUser(context, ref, user),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text('用户列表加载失败：$error'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runSync(BuildContext context, WidgetRef ref) async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _lastSyncResult = null;
    });
    try {
      final result = await ref.read(syncControllerProvider).sync();
      if (mounted) {
        setState(() => _lastSyncResult = result);
        final msg = result.hasError
            ? '同步未完成：${result.error}'
            : '同步完成：推送 ${result.pushed}，拉取 ${result.pulled}，失败 ${result.failed}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('同步出错：$e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _createLocalUser(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
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
        ),
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

  Future<void> _updateRole(
    BuildContext context,
    WidgetRef ref,
    String userId,
    UserRole role,
  ) async {
    try {
      await ref
          .read(userActionsProvider)
          .updateUserRole(userId: userId, role: role);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('用户角色已更新为 ${role.label}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新角色失败：$error')));
      }
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    WidgetRef ref,
    UsersTableData user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('删除用户 ${user.displayName}？'),
          content: const Text('删除后该用户将不再出现在工作空间列表中。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(userActionsProvider).deleteUser(user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已删除用户 ${user.displayName}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除用户失败：$error')));
      }
    }
  }

  Future<void> _bulkUpdateRole(
    BuildContext context,
    WidgetRef ref,
    UserRole role,
  ) async {
    try {
      await ref
          .read(userActionsProvider)
          .updateUsersRole(userIds: _selectedUserIds.toList(), role: role);
      if (mounted) {
        setState(() => _selectedUserIds.clear());
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('批量角色已更新为 ${role.label}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('批量更新角色失败：$error')));
      }
    }
  }

  Future<void> _bulkDeleteUsers(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('删除选中的 ${_selectedUserIds.length} 个用户？'),
          content: const Text('删除后这些用户将不再出现在工作空间列表中。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref
          .read(userActionsProvider)
          .deleteUsers(_selectedUserIds.toList());
      if (mounted) {
        setState(() => _selectedUserIds.clear());
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已批量删除选中用户')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('批量删除失败：$error')));
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

class _UserManagementSummary extends StatelessWidget {
  const _UserManagementSummary({
    required this.total,
    required this.admins,
    required this.members,
  });

  final int total;
  final int admins;
  final int members;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _SummaryChip(
          label: '总用户',
          value: '$total',
          color: Theme.of(context).colorScheme.primary,
        ),
        _SummaryChip(
          label: '管理员',
          value: '$admins',
          color: const Color(0xFF136F63),
        ),
        _SummaryChip(
          label: '普通用户',
          value: '$members',
          color: const Color(0xFFC06C00),
        ),
      ],
    );
  }
}

class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.onPromote,
    required this.onDemote,
    required this.onDelete,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback onPromote;
  final VoidCallback onDemote;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '已选择 $selectedCount 个用户',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: onPromote,
                  child: const Text('批量设为管理员'),
                ),
                FilledButton.tonal(
                  onPressed: onDemote,
                  child: const Text('批量设为普通用户'),
                ),
                OutlinedButton(onPressed: onDelete, child: const Text('批量删除')),
                TextButton(onPressed: onClear, child: const Text('清空选择')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
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
      width: 130,
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
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  const _UserListTile({
    required this.user,
    required this.isActive,
    required this.isCurrentAdmin,
    required this.isSelected,
    required this.onTap,
    required this.onSelectionChanged,
    required this.onRoleChanged,
    required this.onDelete,
  });

  final UsersTableData user;
  final bool isActive;
  final bool isCurrentAdmin;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool>? onSelectionChanged;
  final ValueChanged<UserRole>? onRoleChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final provider = AppUserAuthProvider.fromValue(user.authProvider);
    final role = UserRole.fromValue(user.role);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isActive ? null : onTap,
      child: Card(
        color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              if (isCurrentAdmin && onSelectionChanged != null)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => onSelectionChanged!(value ?? false),
                ),
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
                        Chip(label: Text(role.label)),
                        if (user.wechatUnionId != null)
                          const Chip(label: Text('已绑定微信')),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  if (isActive)
                    const Icon(Icons.check_circle)
                  else
                    const Icon(Icons.chevron_right),
                  if (isCurrentAdmin && onRoleChanged != null)
                    PopupMenuButton<UserRole>(
                      onSelected: onRoleChanged,
                      itemBuilder: (context) => UserRole.values
                          .map(
                            (item) => PopupMenuItem<UserRole>(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                  if (isCurrentAdmin && onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除用户',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.isConfigured,
    required this.pendingCount,
    required this.failedItems,
    required this.isSyncing,
    required this.lastResult,
    required this.onSync,
  });

  final bool isConfigured;
  final AsyncValue<int> pendingCount;
  final AsyncValue<List<SyncQueueTableData>> failedItems;
  final bool isSyncing;
  final SyncResult? lastResult;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '数据同步',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!isConfigured)
            const Text('Supabase 未配置，同步功能不可用。本地数据正常保存。')
          else ...<Widget>[
            pendingCount.when(
              data: (count) => Text('待推送队列：$count 条'),
              loading: () => const Text('读取队列中...'),
              error: (e, _) => Text('队列读取失败：$e'),
            ),
            const SizedBox(height: 8),
            failedItems.when(
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      '失败项：${items.length} 条（最近：${items.first.lastError ?? '未知'}）',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            if (lastResult != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                lastResult!.hasError
                    ? '上次同步：${lastResult!.error}'
                    : '上次同步：推送 ${lastResult!.pushed}，拉取 ${lastResult!.pulled}，失败 ${lastResult!.failed}',
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSyncing ? null : onSync,
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(isSyncing ? '同步中...' : '立即同步'),
            ),
          ],
        ],
      ),
    );
  }
}
