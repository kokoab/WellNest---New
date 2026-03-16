class AppConfig {
  // API base URL – passed via --dart-define=BASE_URL=...
  // Docker (nginx) exposes backend on 8080. Use http://10.0.2.2:8080 for Android emulator.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Reverb WebSocket server (Laravel Reverb). Use a different port than API if both run locally.
  static String get reverbHost => Uri.parse(baseUrl).host;
  static const int reverbPort = int.fromEnvironment('REVERB_PORT', defaultValue: 8081);
  static const String reverbAppKey = String.fromEnvironment('REVERB_APP_KEY', defaultValue: 'wellnest');

  /// Full URL for private channel auth (Laravel returns auth signature here).
  static String get broadcastingAuthUrl => '$baseUrl/api/broadcasting/auth';

  // Example: enable analytics – passed via --dart-define=ANALYTICS_ENABLED=true
  static const bool analyticsEnabled = bool.fromEnvironment(
    'ANALYTICS_ENABLED',
    defaultValue: false,
  );
}
