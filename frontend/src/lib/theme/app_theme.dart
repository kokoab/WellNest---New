import 'package:flutter/material.dart';

/// Brand color palette
const Color kPrimaryGreen = Color(0xFF097333);
const Color kAccentOrange = Color(0xFFEF5026);
const Color kAccentYellow = Color(0xFFF9BD21);
const Color kBackgroundCream = Color(0xFFFDFBF7);
const Color kSurfaceWarmGray = Color(0xFFEAE6DF);
const Color kImagePlaceholderGreen = Color(0xFFE8F1EC);
const Color kBodyTextDark = Color(0xFF333333);
const Color kCaptionGray = Color(0xFF666666);

/// Legacy aliases (for gradual migration)
const Color kWellGreen = kPrimaryGreen;
const Color kNestOrange = kAccentOrange;

/// Display serif (must match `family` in [pubspec.yaml] under `flutter: fonts:`).
const String kFontGeorgiaPro = 'GeorgiaPro';
const String kFontHelveticaNow = 'HelveticaNow';

/// Figma-style tracking in **thousandths of 1em** (e.g. `-30` → `-0.03em` letter-spacing).
const double kGeorgiaProTrackingFigma = -30;

/// Line-height multiplier for Georgia Pro display text (taller, news-masthead feel).
const double kGeorgiaProLineHeightMultiplier = 1.12;

/// Horizontal squeeze for [GeorgiaProDisplaySquish] (narrower = more condensed).
const double kGeorgiaProDisplayScaleX = 0.93;

/// Vertical stretch paired with [kGeorgiaProDisplayScaleX] (taller letterforms).
const double kGeorgiaProDisplayScaleY = 1.07;

/// Letter-spacing in logical pixels for a given [fontSize] (matches Figma tracking).
double georgiaProLetterSpacing(double fontSize) =>
    fontSize * kGeorgiaProTrackingFigma / 1000;

/// Georgia Pro display style: uses **Bold** (weight 700) by default so `GeorgiaPro-Bold.ttf` loads.
TextStyle georgiaProDisplayStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.bold,
  Color? color,
}) =>
    TextStyle(
      fontFamily: kFontGeorgiaPro,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: georgiaProLetterSpacing(fontSize),
      height: kGeorgiaProLineHeightMultiplier,
    );

/// Light theme — warm, organic, vibrant, premium
ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: kFontHelveticaNow,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.light,
    primary: kPrimaryGreen,
    onPrimary: Colors.white,
    secondary: kAccentOrange,
    onSecondary: Colors.white,
    surface: kSurfaceWarmGray,
    onSurface: kBodyTextDark,
    onSurfaceVariant: const Color(0xFF555555),
    outline: const Color(0xFF888888),
  ),
  scaffoldBackgroundColor: kBackgroundCream,
  cardColor: kSurfaceWarmGray,
  appBarTheme: AppBarTheme(
    backgroundColor: kBackgroundCream,
    foregroundColor: kPrimaryGreen,
    elevation: 0,
    iconTheme: const IconThemeData(color: kPrimaryGreen),
    titleTextStyle: georgiaProDisplayStyle(fontSize: 28, color: kPrimaryGreen),
  ),
  textTheme: TextTheme(
    displayLarge: georgiaProDisplayStyle(fontSize: 32, color: kPrimaryGreen),
    headlineMedium: georgiaProDisplayStyle(fontSize: 28, color: kPrimaryGreen),
    titleLarge: georgiaProDisplayStyle(fontSize: 18, color: kPrimaryGreen),
    titleMedium: georgiaProDisplayStyle(fontSize: 18, color: kPrimaryGreen),
    bodyLarge: const TextStyle(
      fontFamily: kFontHelveticaNow,
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: kBodyTextDark,
    ),
    bodyMedium: const TextStyle(
      fontFamily: kFontHelveticaNow,
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: kBodyTextDark,
    ),
    labelSmall: const TextStyle(
      fontFamily: kFontHelveticaNow,
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: kBodyTextDark,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimaryGreen,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 48),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontFamily: kFontHelveticaNow,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    hintStyle: TextStyle(
      color: kPrimaryGreen.withValues(alpha: 0.65),
      fontSize: 16,
    ),
  ),
  focusColor: kPrimaryGreen,
  highlightColor: kPrimaryGreen.withValues(alpha: 0.2),
);

/// Dark theme
ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: kFontHelveticaNow,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.dark,
    primary: kPrimaryGreen,
    onPrimary: Colors.white,
    secondary: kAccentOrange,
    onSecondary: Colors.white,
    surface: const Color(0xFF1E1E1E),
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xFFB0B0B0),
    outline: const Color(0xFF888888),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF2C2C2C),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFF1E1E1E),
    foregroundColor: Colors.white,
    elevation: 0,
    titleTextStyle: georgiaProDisplayStyle(fontSize: 20, color: Colors.white),
  ),
);

/// Brand colors and shared design tokens
class AppColors {
  static const Color primaryGreen = kPrimaryGreen;
  static const Color accentOrange = kAccentOrange;
  static const Color accentYellow = kAccentYellow;
  static const Color backgroundCream = kBackgroundCream;
  static const Color surfaceWarmGray = kSurfaceWarmGray;
  static const Color imagePlaceholderGreen = kImagePlaceholderGreen;
  static const Color bodyText = kBodyTextDark;
  static const Color captionText = kCaptionGray;
  static const Color wellGreen = kPrimaryGreen;
  static const Color nestOrange = kAccentOrange;
}

/// Standardized animation durations
class AppDurations {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 400);
}

/// Standardized curves
class AppCurves {
  static const Curve standard = Curves.easeInOut;
}

const double kMinTapTargetSize = 48.0;

TextStyle georgiaProTextStyle({
  double? fontSize,
  FontWeight fontWeight = FontWeight.bold,
  Color? color,
}) {
  final fs = fontSize;
  return TextStyle(
    fontFamily: kFontGeorgiaPro,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: fs == null ? null : georgiaProLetterSpacing(fs),
    height: kGeorgiaProLineHeightMultiplier,
  );
}

TextStyle helveticaNow({
  double? fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) => TextStyle(
  fontFamily: kFontHelveticaNow,
  fontSize: fontSize,
  fontWeight: fontWeight,
  color: color,
);
