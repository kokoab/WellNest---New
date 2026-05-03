import 'admin_auth_service.dart';
import 'auth_service.dart';
import 'session_persistence.dart';

/// Applies [SessionPersistence.read] to in-memory auth singletons. Call once before [runApp].
Future<void> restoreSessionFromStorage() async {
  final saved = await SessionPersistence.read();
  if (saved == null) return;

  AuthService.instance.setToken(saved.token);
  AuthService.instance.setUserId(saved.userId);
  if (saved.isAdmin) {
    AdminAuthService.instance.setAuth(saved.token, isAdmin: true);
    AdminAuthService.instance.setUserId(saved.userId);
  } else {
    AdminAuthService.instance.clearAuth();
  }
}
