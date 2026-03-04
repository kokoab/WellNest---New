class AppConfig {
  // API base URL – passed via --dart-define=BASE_URL=...
  // Docker (nginx) exposes backend on 8080. Use http://10.0.2.2:8080 for Android emulator.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  // Example: enable analytics – passed via --dart-define=ANALYTICS_ENABLED=true
  static const bool analyticsEnabled = bool.fromEnvironment(
    'ANALYTICS_ENABLED',
    defaultValue: false,
  );

  // You can add more static const fields as needed
  // static const String apiKey = String.fromEnvironment('API_KEY');
}
