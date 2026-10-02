/// Build-time configuration for the real (two-user test) backend.
///
/// Values come from `--dart-define` (CI reads them from GitHub repository
/// *variables*). The Supabase URL and anon/publishable key are PUBLIC by design
/// (they only allow what Row Level Security allows). The service_role / secret
/// key must never be here.
class BackendConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Base of the invitation link, e.g. https://drivetalk-test.pages.dev
  /// (empty → the share message falls back to "download + code").
  static const inviteBaseUrl = String.fromEnvironment('INVITE_BASE_URL');

  /// Where testers download the Android app.
  static const apkUrl = String.fromEnvironment(
    'APK_URL',
    defaultValue: 'https://github.com/fenetnet/Drivetalk/releases/download/prototype/drivetalk-prototype.apk',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Host only (never the key) — safe to show in diagnostics.
  static String get backendHost =>
      supabaseUrl.isEmpty ? '—' : Uri.tryParse(supabaseUrl)?.host ?? '?';
}
