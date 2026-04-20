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
    // Resolve userId: use explicitly selected, or fall back to first in list.
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
      // Switch to selected user
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

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(userListProvider);

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
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                users.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Text('暂无用户，请先注册。', textAlign: TextAlign.center);
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
                  loading: () => const Center(child: CircularProgressIndicator()),
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
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
