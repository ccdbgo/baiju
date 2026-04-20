class AppEnvironment {
  const AppEnvironment({
    required this.name,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.enablePush,
    required this.enableVerboseLogs,
  });

  final String name;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool enablePush;
  final bool enableVerboseLogs;
}
