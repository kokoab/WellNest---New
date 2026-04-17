import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand color palette
const Color kPrimaryGreen = Color(0xFF097333);
const Color kAccentOrange = Color(0xFFEF5026);
const Color kAccentYellow = Color(0xFFF9BD21);
const Color kBackgroundCream = Color(0xFFFDFBF7);
const Color kSurfaceWarmGray = Color(0xFFEAE6DF);
const Color kImagePlaceholderGreen = Color(0xFFE8F1EC);
const Color kBodyTextDark = Color(0xFF333333);
const Color kCaptionGray = Color(0xFF666666);
const Color kDarkBackground = Color(0xFF101714);
const Color kDarkSurface = Color(0xFF17211D);
const Color kDarkSurfaceElevated = Color(0xFF203029);
const Color kDarkSurfaceBright = Color(0xFF2A3B33);
const Color kDarkPrimaryGreen = Color(0xFF3CB16C);
const Color kDarkAccentOrange = Color(0xFFFF8B6B);
const Color kDarkTextPrimary = Color(0xFFF3F7F4);
const Color kDarkTextSecondary = Color(0xFFBECCC4);
const Color kDarkOutline = Color(0xFF4E6159);

/// Legacy aliases (for gradual migration)
const Color kWellGreen = kPrimaryGreen;
const Color kNestOrange = kAccentOrange;

ThemeData get lightTheme {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.light,
  ).copyWith(
    primary: kPrimaryGreen,
    onPrimary: Colors.white,
    secondary: kAccentOrange,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: kBodyTextDark,
    onSurfaceVariant: const Color(0xFF5F645F),
    outline: const Color(0xFFD4D9D3),
    outlineVariant: const Color(0xFFE7EBE6),
    shadow: Colors.black,
    scrim: Colors.black,
  );
  final textTheme = _buildTextTheme(
    titleColor: kPrimaryGreen,
    bodyColor: kBodyTextDark,
    mutedColor: kCaptionGray,
  );
  return _buildTheme(
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kBackgroundCream,
    cardColor: Colors.white,
    textTheme: textTheme,
    appBarForegroundColor: kPrimaryGreen,
    appBarBackgroundColor: kBackgroundCream,
    inputFillColor: Colors.white,
    panelColor: const Color(0xFFF6F3ED),
    panelBorderColor: const Color(0xFFE5E0D9),
    shadowColor: Colors.black.withValues(alpha: 0.06),
  );
}

ThemeData get darkTheme {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kDarkPrimaryGreen,
    brightness: Brightness.dark,
  ).copyWith(
    primary: kDarkPrimaryGreen,
    onPrimary: const Color(0xFF062B14),
    secondary: kDarkAccentOrange,
    onSecondary: const Color(0xFF3B1207),
    error: const Color(0xFFFF8A80),
    onError: const Color(0xFF360C08),
    surface: kDarkSurface,
    onSurface: kDarkTextPrimary,
    onSurfaceVariant: kDarkTextSecondary,
    outline: kDarkOutline,
    outlineVariant: const Color(0xFF34443D),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFFE7EEE9),
    onInverseSurface: const Color(0xFF16211C),
    inversePrimary: kPrimaryGreen,
  );
  final textTheme = _buildTextTheme(
    titleColor: kDarkTextPrimary,
    bodyColor: kDarkTextPrimary,
    mutedColor: kDarkTextSecondary,
  );
  return _buildTheme(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kDarkBackground,
    cardColor: kDarkSurfaceElevated,
    textTheme: textTheme,
    appBarForegroundColor: kDarkTextPrimary,
    appBarBackgroundColor: kDarkBackground,
    inputFillColor: kDarkSurfaceElevated,
    panelColor: kDarkSurfaceBright,
    panelBorderColor: const Color(0xFF27352F),
    shadowColor: Colors.black.withValues(alpha: 0.24),
  );
}

/// Typography inspired by **Meta-style** product UI (not a font clone): a clear neo-grotesque
/// sans, strong headline hierarchy, slight negative tracking on titles, and relaxed line
/// height for readable “feed” body copy. Face: [Plus Jakarta Sans](https://fonts.google.com/specimen/Plus+Jakarta+Sans).
String? _appFontFamilyCache;

/// Resolved [TextStyle.fontFamily] for the app UI font (cached after first use).
String get kFontAppFamily =>
    _appFontFamilyCache ??= GoogleFonts.plusJakartaSans().fontFamily!;

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

class AppRadii {
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
}

TextStyle appText({
  double? fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
  double? letterSpacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

ThemeData _buildTheme({
  required Brightness brightness,
  required ColorScheme colorScheme,
  required Color scaffoldBackgroundColor,
  required Color cardColor,
  required TextTheme textTheme,
  required Color appBarForegroundColor,
  required Color appBarBackgroundColor,
  required Color inputFillColor,
  required Color panelColor,
  required Color panelBorderColor,
  required Color shadowColor,
}) {
  final isDark = brightness == Brightness.dark;
  final outlineBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
    borderSide: BorderSide(color: panelBorderColor),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: kFontAppFamily,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    canvasColor: scaffoldBackgroundColor,
    cardColor: cardColor,
    dividerColor: colorScheme.outline,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBackgroundColor,
      foregroundColor: appBarForegroundColor,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: appBarForegroundColor),
      actionsIconTheme: IconThemeData(color: appBarForegroundColor),
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        color: appBarForegroundColor,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      shadowColor: shadowColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: panelBorderColor),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: panelColor,
        disabledForegroundColor: colorScheme.onSurfaceVariant,
        minimumSize: const Size(double.infinity, 52),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: panelColor,
        disabledForegroundColor: colorScheme.onSurfaceVariant,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.outline),
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: panelColor,
      selectedColor: colorScheme.primary.withValues(alpha: 0.12),
      secondarySelectedColor: colorScheme.secondary.withValues(alpha: 0.16),
      side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.7)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: textTheme.labelLarge ?? const TextStyle(),
      secondaryLabelStyle:
          (textTheme.labelLarge ?? const TextStyle()).copyWith(
        color: colorScheme.primary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.primary,
      ),
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIconColor: colorScheme.onSurfaceVariant,
      border: outlineBorder,
      enabledBorder: outlineBorder,
      focusedBorder: outlineBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      errorBorder: outlineBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: outlineBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.error, width: 1.4),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline.withValues(alpha: 0.7),
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: panelColor,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      actionTextColor: colorScheme.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colorScheme.primary,
      selectionColor: colorScheme.primary.withValues(alpha: 0.18),
      selectionHandleColor: colorScheme.primary,
    ),
    splashColor: colorScheme.primary.withValues(alpha: 0.12),
    highlightColor: colorScheme.primary.withValues(alpha: 0.08),
    hoverColor: colorScheme.onSurface.withValues(alpha: 0.04),
    focusColor: colorScheme.primary.withValues(alpha: 0.18),
  );
}

TextTheme _buildTextTheme({
  required Color titleColor,
  required Color bodyColor,
  required Color mutedColor,
}) {
  const headlineTracking = -0.4;
  const titleTracking = -0.2;

  return TextTheme(
    displayLarge: appText(
      fontSize: 34,
      fontWeight: FontWeight.bold,
      color: titleColor,
      letterSpacing: headlineTracking,
    ),
    displayMedium: appText(
      fontSize: 30,
      fontWeight: FontWeight.bold,
      color: titleColor,
      letterSpacing: headlineTracking,
    ),
    headlineSmall: appText(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: titleColor,
      letterSpacing: headlineTracking,
    ),
    headlineMedium: appText(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: titleColor,
      letterSpacing: headlineTracking,
    ),
    titleLarge: appText(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: titleColor,
      letterSpacing: titleTracking,
    ),
    titleMedium: appText(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: titleColor,
      letterSpacing: titleTracking,
    ),
    titleSmall: appText(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: bodyColor,
      letterSpacing: 0.1,
    ),
    bodyLarge: appText(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: bodyColor,
      height: 1.5,
    ),
    bodyMedium: appText(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: bodyColor,
      height: 1.5,
    ),
    bodySmall: appText(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: mutedColor,
      height: 1.42,
    ),
    labelLarge: appText(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: bodyColor,
      letterSpacing: 0.15,
    ),
    labelMedium: appText(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: mutedColor,
      letterSpacing: 0.1,
    ),
    labelSmall: appText(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: mutedColor,
      letterSpacing: 0.12,
    ),
  );
}
