import '../config/app_config.dart';

/// Rewrites storage URLs to use the app [AppConfig.baseUrl] host (emulator/Docker safe).
String? resolveStorageDisplayUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final base = AppConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
  if (url.startsWith('http')) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.startsWith('/storage/')) {
      return '$base${uri.path}';
    }
  }
  if (url.startsWith('/')) return base + url;
  return url;
}
