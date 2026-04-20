import 'package:baiju_app/app/config/app_env.dart';
import 'package:baiju_app/app/config/app_environment.dart';
import 'package:baiju_app/core/notifications/app_notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppEnvironment> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    final environment = resolveAppEnvironment();
    await AppNotificationService.instance.initialize();
    await _initializeSupabase(environment);

    return environment;
  }

  static Future<void> _initializeSupabase(AppEnvironment environment) async {
    if (environment.supabaseUrl.isEmpty ||
        environment.supabaseAnonKey.isEmpty) {
      return;
    }

    await Supabase.initialize(
      url: environment.supabaseUrl,
      anonKey: environment.supabaseAnonKey,
    );
  }
}
