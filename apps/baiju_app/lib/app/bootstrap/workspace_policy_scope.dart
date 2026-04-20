import 'dart:async';

import 'package:baiju_app/features/todo/infrastructure/todo_repository.dart';
import 'package:baiju_app/features/todo/presentation/providers/todo_providers.dart';
import 'package:baiju_app/features/user/domain/user_preferences.dart';
import 'package:baiju_app/features/user/presentation/providers/user_preferences_providers.dart';
import 'package:baiju_app/features/user/presentation/providers/user_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workspacePolicyControllerProvider =
    Provider<WorkspacePolicyController>((ref) {
  final todoRepository = ref.watch(todoRepositoryProvider);
  return WorkspacePolicyController(todoRepository);
});

class WorkspacePolicyScope extends ConsumerStatefulWidget {
  const WorkspacePolicyScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<WorkspacePolicyScope> createState() => _WorkspacePolicyScopeState();
}

class _WorkspacePolicyScopeState extends ConsumerState<WorkspacePolicyScope> {
  bool _running = false;

  @override
  void initState() {
    super.initState();
    unawaited(_applyPolicies());
  }

  Future<void> _applyPolicies() async {
    if (_running) {
      return;
    }

    _running = true;
    try {
      final preferences = await ref.read(userPreferencesProvider.future);
      await ref
          .read(workspacePolicyControllerProvider)
          .apply(preferences);
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserWorkspaceProvider, (previous, next) {
      if (previous?.userId != next.userId) {
        unawaited(_applyPolicies());
      }
    });
    ref.listen<AsyncValue<UserPreferences>>(userPreferencesProvider, (_, next) {
      next.whenData((_) => unawaited(_applyPolicies()));
    });
    return widget.child;
  }
}

class WorkspacePolicyController {
  const WorkspacePolicyController(this._todoRepository);

  final TodoRepository _todoRepository;

  Future<void> apply(UserPreferences preferences) async {
    if (preferences.autoRolloverTodosToToday) {
      await _todoRepository.rolloverOverdueTodosToToday();
    }
  }
}
