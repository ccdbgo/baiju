import 'package:baiju_app/app/router/app_router.dart';
import 'package:baiju_app/features/user/presentation/providers/auth_state_provider.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserAvatarButton extends ConsumerWidget {
  const UserAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeUserProfileProvider);
    final displayName = profile.maybeWhen(
      data: (u) => u?.displayName ?? '?',
      orElse: () => '?',
    );
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => _showProfileSheet(context, ref, displayName),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: CircleAvatar(
          radius: 16,
          child: Text(initial, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }

  void _showProfileSheet(
    BuildContext context,
    WidgetRef ref,
    String displayName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _UserProfileSheet(displayName: displayName),
      ),
    );
  }
}

class _UserProfileSheet extends ConsumerStatefulWidget {
  const _UserProfileSheet({required this.displayName});
  final String displayName;

  @override
  ConsumerState<_UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends ConsumerState<_UserProfileSheet> {
  late final TextEditingController _nameCtrl;
  final _oldPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _saving = false;
  String? _nameError;
  String? _pwError;
  String? _pwSuccess;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.displayName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '名称不能为空');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    try {
      final userId = ref.read(currentUserWorkspaceProvider).userId;
      await ref.read(userRepositoryProvider).updateDisplayName(userId, name);
      if (mounted) setState(() => _nameError = null);
    } catch (e) {
      if (mounted) setState(() => _nameError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePassword() async {
    final oldPw = _oldPwCtrl.text;
    final newPw = _newPwCtrl.text.trim();
    if (newPw.isEmpty) {
      setState(() => _pwError = '新密码不能为空');
      return;
    }
    setState(() {
      _saving = true;
      _pwError = null;
      _pwSuccess = null;
    });
    try {
      final userId = ref.read(currentUserWorkspaceProvider).userId;
      final repo = ref.read(userRepositoryProvider);
      final hasPassword = await repo.userHasPassword(userId);
      if (hasPassword) {
        final ok = await repo.verifyUserPassword(userId, oldPw);
        if (!ok) {
          setState(() => _pwError = '原密码错误');
          return;
        }
      }
      await repo.setUserPassword(userId, newPw);
      // Update persisted session with new userId (password changed, still same user).
      await ref.read(authStateProvider.notifier).setAuthenticated(userId);
      _oldPwCtrl.clear();
      _newPwCtrl.clear();
      if (mounted) setState(() => _pwSuccess = '密码已更新');
    } catch (e) {
      if (mounted) setState(() => _pwError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authStateProvider.notifier).setUnauthenticated();
    if (mounted) Navigator.of(context).pop();
    AppRouter.router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('个人资料', style: theme.textTheme.titleLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Display name ---
          Text('用户名', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _saving ? null : _saveName,
                child: const Text('保存'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Password ---
          Text('修改密码', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _oldPwCtrl,
            obscureText: _obscureOld,
            decoration: InputDecoration(
              labelText: '原密码（无密码可留空）',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureOld = !_obscureOld),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPwCtrl,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: '新密码',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
              errorText: _pwError,
            ),
          ),
          if (_pwSuccess != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(_pwSuccess!, style: TextStyle(color: theme.colorScheme.primary)),
          ],
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _saving ? null : _savePassword,
            child: const Text('更新密码'),
          ),
          const SizedBox(height: 24),

          // --- Logout ---
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
