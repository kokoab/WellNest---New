class AppConfig {
  // API base URL – passed via --dart-define=BASE_URL=...
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8080', // default for Android emulator
  );

  // Example: enable analytics – passed via --dart-define=ANALYTICS_ENABLED=true
  static const bool analyticsEnabled = bool.fromEnvironment(
    'ANALYTICS_ENABLED',
    defaultValue: false,
  );

  // You can add more static const fields as needed
  // static const String apiKey = String.fromEnvironment('API_KEY');
}
