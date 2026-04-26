import 'package:flutter/material.dart';

/// Admin-specific color palette.
/// Deep Navy/Graphite theme to differentiate from user-facing app.
class AdminColors {
  // Primary Admin Colors
  static const Color deepNavy = Color(0xFF1A2332);
  static const Color graphite = Color(0xFF2D3748);
  static const Color slate = Color(0xFF4A5568);
  static const Color lightSlate = Color(0xFF718096);
  
  // Admin Accent Colors
  static const Color adminAccent = Color(0xFF4FD1C5);
  static const Color adminAccentLight = Color(0xFF81E6D9);
  static const Color adminAccentDark = Color(0xFF319795);
  
  // Status Colors
  static const Color success = Color(0xFF48BB78);
  static const Color warning = Color(0xFFECC94B);
  static const Color danger = Color(0xFFFC8181);
  static const Color info = Color(0xFF63B3ED);
  
  // Chart Colors
  static const Color chartLine1 = Color(0xFF4FD1C5);
  static const Color chartLine2 = Color(0xFF63B3ED);
  static const Color chartLine3 = Color(0xFFFC8181);
  static const Color chartLine4 = Color(0xFFECC94B);
  static const Color chartFill1 = Color(0x334FD1C5);
  static const Color chartFill2 = Color(0x3363B3ED);
  static const Color chartFill3 = Color(0x33FC8181);
  
  // Background Colors
  static const Color adminBackground = Color(0xFF1A202C);
  static const Color cardBackground = Color(0xFF2D3748);
  static const Color surfaceLight = Color(0xFFEDF2F7);
}

/// Admin theme data for the app.
class AdminTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AdminColors.deepNavy,
      scaffoldBackgroundColor: AdminColors.adminBackground,
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.adminAccent,
        secondary: AdminColors.adminAccentLight,
        surface: AdminColors.cardBackground,
        error: AdminColors.danger,
        onPrimary: Colors.white,
        onSecondary: AdminColors.deepNavy,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.deepNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AdminColors.cardBackground,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
        headlineMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        headlineSmall: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        titleLarge: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        bodyLarge: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: AdminColors.lightSlate,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: AdminColors.lightSlate,
          fontSize: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.adminAccent,
          foregroundColor: AdminColors.deepNavy,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.adminAccent,
          side: const BorderSide(color: AdminColors.adminAccent),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.graphite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.slate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AdminColors.adminAccent),
        ),
        labelStyle: const TextStyle(color: AdminColors.lightSlate),
        hintStyle: const TextStyle(color: AdminColors.slate),
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        dataTextStyle: TextStyle(
          color: AdminColors.lightSlate,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.slate,
        thickness: 1,
      ),
    );
  }
}