class AppConfig {
  static const bool supabaseEnabled = bool.fromEnvironment(
    'SUPABASE_ENABLED',
    defaultValue: true,
  );
}
