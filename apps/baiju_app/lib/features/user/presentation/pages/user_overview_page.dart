import 'package:baiju_app/app/router/app_router.dart';
import 'package:baiju_app/features/user/presentation/pages/user_page.dart';
import 'package:flutter/material.dart';

class UserOverviewPage extends StatelessWidget {
  const UserOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户总览'),
        actions: <Widget>[
          FilledButton.tonal(
            onPressed: () => AppRouter.router.go('/today'),
            child: const Text('进入应用'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: const UserPage(),
    );
  }
}
