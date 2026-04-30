import 'dart:async';

import 'package:baiju_app/core/notifications/notification_providers.dart';
import 'package:baiju_app/core/notifications/reminder_event.dart';
import 'package:baiju_app/core/notifications/reminder_ticker.dart';
import 'package:baiju_app/core/sync/sync_providers.dart';
import 'package:baiju_app/features/user/domain/user_models.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
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
  StreamSubscription<ReminderEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_syncManagedReminders());
    final ticker = ref.read(reminderTickerProvider);
    ticker.start();
    _eventSub = ticker.events.listen(_onReminderEvent);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    ref.read(reminderTickerProvider).stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onReminderEvent(ReminderEvent event) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(event.title),
        content: Text(event.body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
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
