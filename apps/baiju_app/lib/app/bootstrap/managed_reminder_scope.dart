import 'dart:async';

import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/core/notifications/reminder_ticker.dart';
import 'package:baiju_app/core/sync/sync_providers.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ManagedReminderScope extends ConsumerStatefulWidget {
  const ManagedReminderScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<ManagedReminderScope> createState() =>
      _ManagedReminderScopeState();
}

class _ManagedReminderScopeState extends ConsumerState<ManagedReminderScope>
    with WidgetsBindingObserver {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncManagedReminders());
    ref.read(reminderTickerProvider).start();
  }

  @override
  void dispose() {
    ref.read(reminderTickerProvider).stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncManagedReminders());
      ref.read(reminderTickerProvider).start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ref.read(reminderTickerProvider).stop();
    }
  }

  Future<void> _syncManagedReminders() async {
    if (_syncing) {
      return;
    }

    _syncing = true;
    try {
      final preferences = await ref.read(userPreferencesProvider.future);
      if (!preferences.autoSyncOnLaunch) {
        return;
      }
      await ref.read(reminderSyncControllerProvider).syncAll();
      if (mounted) {
        ref.invalidate(pendingReminderCountProvider);
      }
      // Also push any pending local changes to Supabase (fire-and-forget).
      unawaited(ref.read(syncControllerProvider).pushOnly());
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserWorkspace>(currentUserWorkspaceProvider, (previous, next) {
      if (previous?.userId != next.userId) {
        unawaited(_syncManagedReminders());
      }
    });
    return widget.child;
  }
}
