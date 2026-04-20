import 'package:baiju_app/app/router/app_router.dart';
import 'package:baiju_app/features/user/presentation/providers/auth_state_provider.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _passwordController = TextEditingController();
  String? _selectedUserId;
  String? _error;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final users = ref.read(userListProvider).value;
    final userId = _selectedUserId ?? users?.firstOrNull?.id;
    if (userId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final actions = ref.read(userActionsProvider);
      final hasPassword = await actions.userHasPassword(userId);
      if (hasPassword) {
        final ok = await actions.verifyUserPassword(
          userId,
          _passwordController.text,
        );
        if (!ok) {
          setState(() => _error = '密码错误');
          return;
        }
      }
      final workspace = await ref.read(userRepositoryProvider).switchUser(
        userId: userId,
        deviceId: ref.read(currentUserWorkspaceProvider).deviceId,
      );
      ref.read(currentUserWorkspaceProvider.notifier).setWorkspace(workspace);
      await ref.read(authStateProvider.notifier).setAuthenticated(userId);
      AppRouter.router.go('/today');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithWechat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final existing = await repo.findLocalWechatUser();

      if (existing != null && mounted) {
        // 本地已有微信账号，弹确认框
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('微信登录'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('检测到本地已有微信账号：'),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (existing.avatarUrl != null)
                      CircleAvatar(
                        backgroundImage: NetworkImage(existing.avatarUrl!),
                        radius: 18,
                      )
                    else
                      const CircleAvatar(
                        radius: 18,
                        child: Icon(Icons.person, size: 18),
                      ),
                    const SizedBox(width: 10),
                    Text(
                      existing.displayName,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('是否以此账号登录？'),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认登录'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      // 调用微信登录（mock 或真实）
      final workspace = await repo.signInWithWechat(
        currentWorkspace: ref.read(currentUserWorkspaceProvider),
      );
      ref.read(currentUserWorkspaceProvider.notifier).setWorkspace(workspace);
      await ref
          .read(authStateProvider.notifier)
          .setAuthenticated(workspace.userId);
      AppRouter.router.go('/today');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(userListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '登录',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                users.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Text(
                        '暂无用户，请先注册。',
                        textAlign: TextAlign.center,
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedUserId ?? items.first.id,
                      decoration: const InputDecoration(
                        labelText: '选择用户',
                        border: OutlineInputBorder(),
                      ),
                      items: items
                          .map(
                            (u) => DropdownMenuItem(
                              value: u.id,
                              child: Text(u.displayName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedUserId = v;
                        _error = null;
                        _passwordController.clear();
                      }),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('加载失败：$e'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: '密码',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('登录'),
                ),
                const SizedBox(height: 12),
                // 分割线
                Row(
                  children: <Widget>[
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '其他登录方式',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                // 微信登录按钮
                OutlinedButton.icon(
                  onPressed: _loading ? null : _loginWithWechat,
                  icon: const _WechatIcon(),
                  label: const Text('微信登录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF07C160),
                    side: const BorderSide(color: Color(0xFF07C160)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => AppRouter.router.go('/register'),
                  child: const Text('注册新用户'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WechatIcon extends StatelessWidget {
  const _WechatIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chat_bubble_outline,
      size: 18,
      color: Color(0xFF07C160),
    );
  }
}
