import 'dart:async';

import 'package:baiju_app/app/router/app_router.dart';
import 'package:baiju_app/features/user/presentation/providers/auth_state_provider.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserScope extends ConsumerStatefulWidget {
  const UserScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<UserScope> createState() => _UserScopeState();
}

class _UserScopeState extends ConsumerState<UserScope> {
  bool _initializing = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await ref.read(userBootstrapControllerProvider).initialize();
      final workspace = ref.read(currentUserWorkspaceProvider);
      final repository = ref.read(userRepositoryProvider);
      final authNotifier = ref.read(authStateProvider.notifier);

      // Try to restore a persisted session first.
      final restoredUserId = await authNotifier.restoreSession();
      if (restoredUserId != null && restoredUserId == workspace.userId) {
        // Session valid — already authenticated.
      } else {
        // No valid session: check if a password is required.
        final needsAuth = await repository.userHasPassword(workspace.userId);
        if (!needsAuth) {
          // No password — auto-authenticate and persist.
          await authNotifier.setAuthenticated(workspace.userId);
        } else {
          await authNotifier.setUnauthenticated();
        }
      }
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) {
        setState(() => _initializing = false);
        if (_error == null) {
          final authenticated = ref.read(authStateProvider);
          AppRouter.router.go(authenticated ? '/today' : '/login');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        if (_initializing)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '正在初始化用户工作空间...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_error != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.transparent,
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '用户初始化失败：$_error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

