import 'admin_auth_service.dart';
import 'auth_service.dart';
import 'session_persistence.dart';

/// Applies [SessionPersistence.read] to in-memory auth singletons. Call once before [runApp].
Future<void> restoreSessionFromStorage() async {
  final saved = await SessionPersistence.read();
  if (saved == null) return;

  AuthService.instance.setToken(saved.token);
  if (saved.isAdmin) {
    AdminAuthService.instance.setAuth(saved.token, isAdmin: true);
  } else {
    AdminAuthService.instance.clearAuth();
  }
}
