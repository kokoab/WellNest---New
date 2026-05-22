class AppConfig {
  /// Your Mac's static local-network IP address.
  /// Both Android and iOS physical devices use this to reach the backend
  /// as long as the phone and Mac are on the same WiFi network.
  /// To find your Mac IP: run `ipconfig getifaddr en0` in Terminal.
  /// Override at build time with --dart-define=MAC_IP=<new-ip>
  static const String macIp = String.fromEnvironment(
    'MAC_IP',
    defaultValue: '10.176.54.244',
  );

  // API base URL – passed via --dart-define=BASE_URL=...
  // Docker (nginx) exposes backend on 8080.
  // Physical devices (Android/iOS) use macIp; Android emulator uses 10.0.2.2.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.176.54.244:8080',
  );

  /// Reverb WebSocket server (Laravel Reverb). Use a different port than API if both run locally.
  static String get reverbHost => Uri.parse(baseUrl).host;
  static const int reverbPort = int.fromEnvironment('REVERB_PORT', defaultValue: 8081);
  static const String reverbAppKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    // Match backend .env default for local Docker setup.
    defaultValue: 'efcct5mu8lg3nxzgpixd',
  );

  /// Full URL for private channel auth (Laravel returns auth signature here).
  static String get broadcastingAuthUrl => '$baseUrl/api/broadcasting/auth';

  // Example: enable analytics – passed via --dart-define=ANALYTICS_ENABLED=true
  static const bool analyticsEnabled = bool.fromEnvironment(
    'ANALYTICS_ENABLED',
    defaultValue: false,
  );
}
