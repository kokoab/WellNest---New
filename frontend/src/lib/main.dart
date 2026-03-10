import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_app/providers/theme_provider.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/screens/admin_dashboard.dart';
import 'package:my_app/screens/admin_login.dart';
import 'package:my_app/screens/user_dashboard.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/screens/register_screen.dart';
import 'package:my_app/screens/splash_screen.dart';
import 'package:my_app/screens/saved_recipes_screen.dart';

void main() {
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
          home: const WellnestSplashScreen(),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/admin_login': (context) => const AdminLoginScreen(),
            '/admin_dashboard': (context) => const AdminDashboard(),
            '/dashboard': (context) => const UserDashboard(),
            '/saved-recipes': (context) => const SavedRecipesScreen(),
          },
        ),
      ),
    );
  }
}