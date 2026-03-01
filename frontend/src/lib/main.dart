import 'package:flutter/material.dart';
import 'package:my_app/screens/admin_dashboard.dart';
import 'package:my_app/screens/admin_login.dart';
import 'package:my_app/screens/user_dashboard.dart';
// Import your screens
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/screens/register_screen.dart';
import 'package:my_app/screens/splash_screen.dart';
// Note: Assuming you already have a welcome_screen.dart, but the final provided design
// just shows a splash screen, so we will treat it as the main initial entry point.
// You might want to rename your welcome_screen.dart to splash_screen.dart.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wellnest',
      debugShowCheckedModeBanner: false, // Cleaner look
      theme: ThemeData(
        // The overall theme will use the primary brand green as a seed
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF097333)),
        useMaterial3: true,
      ),
      // Set the Splash screen as the home
      home: const AdminDashboard(), // We will reuse and connect to your WelcomeScreen from here
      // Define routes for named navigation
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/dashboard': (context) => const UserDashboard(), // Add this line
      },
    );
  }
}