import 'package:baiju_app/app/config/app_environment.dart';
import 'package:baiju_app/app/bootstrap/managed_reminder_scope.dart';
import 'package:baiju_app/app/bootstrap/preview_seed_scope.dart';
import 'package:baiju_app/app/bootstrap/user_scope.dart';
import 'package:baiju_app/app/bootstrap/workspace_policy_scope.dart';
import 'package:baiju_app/app/router/app_router.dart';
import 'package:baiju_app/app/theme/app_theme.dart';
import 'package:baiju_app/shared/constants/app_constants.dart';
import 'package:flutter/material.dart';

class BaijuApp extends StatelessWidget {
  const BaijuApp({
    required this.environment,
    super.key,
  });

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final content = PreviewSeedScope(
          enabled: environment.name != 'prod',
          child: WorkspacePolicyScope(
            child: ManagedReminderScope(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );

        final scopedContent = UserScope(child: content);

        return scopedContent;
      },
    );
  }
}
