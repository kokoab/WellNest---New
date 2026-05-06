import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:my_app/providers/theme_provider.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/screens/admin_dashboard.dart';
import 'package:my_app/screens/admin_login.dart';
import 'package:my_app/screens/user_dashboard.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/screens/forgot_password_screen.dart';
import 'package:my_app/screens/register_screen.dart';
import 'package:my_app/screens/splash_screen.dart';
import 'package:my_app/screens/saved_recipes_screen.dart';
import 'package:my_app/screens/conversations_list_screen.dart';
import 'package:my_app/services/admin_auth_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/session_restore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await restoreSessionFromStorage();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Wellnest',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) => FocusTraversalGroup(
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      Navigator.maybePop(context);
                      return null;
                    },
                  ),
                },
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
          home: const _PrecacheWrapper(child: _AppInitialHome()),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/reset-password': (context) => const ForgotPasswordScreen(),
            '/register': (context) => const RegisterScreen(),
            '/admin_login': (context) => const AdminLoginScreen(),
            '/admin_dashboard': (context) => const AdminDashboard(),
            '/dashboard': (context) => const UserDashboard(),
            '/saved-recipes': (context) => const SavedRecipesScreen(),
            '/conversations': (context) => const ConversationsListScreen(),
          },
        ),
      ),
    );
  }
}

/// After [restoreSessionFromStorage], sends admins and users to their dashboard; guests see splash.
class _AppInitialHome extends StatelessWidget {
  const _AppInitialHome();

  @override
  Widget build(BuildContext context) {
    if (AdminAuthService.instance.isLoggedIn) {
      return const AdminDashboard();
    }
    if (AuthService.instance.isLoggedIn) {
      return const UserDashboard();
    }
    return const WellnestSplashScreen();
  }
}

/// Precache logo so login/register/dashboard headers load instantly.
class _PrecacheWrapper extends StatefulWidget {
  final Widget child;

  const _PrecacheWrapper({required this.child});

  @override
  State<_PrecacheWrapper> createState() => _PrecacheWrapperState();
}

class _PrecacheWrapperState extends State<_PrecacheWrapper> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheOnce();
  }

  static bool _precached = false;

  void _precacheOnce() {
    if (_precached) return;
    _precached = true;
    precacheImage(const AssetImage('lib/assets/images/logo1.png'), context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
