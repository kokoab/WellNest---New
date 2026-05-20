import 'package:wellnest/config/app_config.dart';

/// Ensures recipe images load when the API returns a host-relative path or a
/// full URL whose origin does not match [AppConfig.baseUrl] (common on web).
String? resolveRecipeImageUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  var raw = url.trim();
  if (raw.startsWith('//')) raw = 'https:$raw';

  final apiBase = AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
  final apiUri = Uri.parse(apiBase);

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    try {
      final uri = Uri.parse(raw);
      // Same storage path as Laravel `/storage/...` — always load via configured API base.
      if (uri.path.contains('/storage/')) {
        return apiUri.replace(path: uri.path, query: uri.query).toString();
      }
      return raw;
    } catch (_) {
      return raw;
    }
  }

  final path = raw.startsWith('/') ? raw : '/$raw';
  return '$apiBase$path';
}
