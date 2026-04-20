import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAuthKey = 'auth_verified_user_id';

final authStateProvider = NotifierProvider<AuthStateNotifier, bool>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Call after successful password verification. Persists the userId so
  /// a page refresh does not require re-login.
  Future<void> setAuthenticated(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAuthKey, userId);
    state = true;
  }

  /// Returns the persisted userId if the user was previously authenticated,
  /// null otherwise.
  Future<String?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kAuthKey);
    if (userId != null) state = true;
    return userId;
  }

  Future<void> setUnauthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthKey);
    state = false;
  }
}
