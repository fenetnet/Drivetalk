/// Build-time configuration for the real (two-user test) backend.
///
/// Values come from `--dart-define` (CI reads them from GitHub repository
/// *variables*). The Supabase URL and anon/publishable key are PUBLIC by design
/// (they only allow what Row Level Security allows). The service_role / secret
/// key must never be here.
class BackendConfig {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The owner's test project. Both values are PUBLIC (publishable key);
  /// build variables override them.
  static const _defaultUrl = 'https://isjgrdiiawhyxzvzdkva.supabase.co';
  static const _defaultKey = 'sb_publishable_2qohPSKh7lkPXblHVmPyFg_Xu6shuEn';

  static String get supabaseUrl {
    var u = _url.trim();
    if (u.isEmpty) return _defaultUrl;
    if (!u.startsWith('http')) u = 'https://$u';
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  static String get supabaseAnonKey =>
      _key.trim().isEmpty ? _defaultKey : _key.trim();

  /// Base of the invitation link, e.g. https://drivetalk-test.pages.dev
  /// (empty → the share message falls back to "download + code").
  static const inviteBaseUrl = String.fromEnvironment('INVITE_BASE_URL');

  /// The Google Play build (`--dart-define=STORE=true`): Google Play
  /// updates the app, and invitations point to the store page.
  static const store = bool.fromEnvironment('STORE');

  static const playUrl =
      'https://play.google.com/store/apps/details?id=app.drivetalk.drivetalk';

  static const _apkUrl = String.fromEnvironment(
    'APK_URL',
    defaultValue: 'https://github.com/fenetnet/Drivetalk/releases/download/prototype/drivetalk-prototype.apk',
  );

  /// Where people get the app: the APK for testers, the store page in the
  /// Google Play build.
  static String get apkUrl => store ? playUrl : _apkUrl;

  /// The download page (with the install steps), next to the APK.
  static String get downloadPageUrl => store
      ? playUrl
      : _apkUrl.contains('/releases/download/')
      ? '${_apkUrl.substring(0, _apkUrl.indexOf('/releases/download/'))}'
            '/releases/tag/prototype'
      : _apkUrl;

  /// {"build": N} of the newest published version (written by CI).
  static String get latestVersionUrl =>
      '${_apkUrl.substring(0, _apkUrl.lastIndexOf('/'))}/version.json';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Host only (never the key) — safe to show in diagnostics.
  static String get backendHost =>
      supabaseUrl.isEmpty ? '—' : Uri.tryParse(supabaseUrl)?.host ?? '?';
}
