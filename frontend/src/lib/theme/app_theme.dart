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

/// Discover hero wash (soft pale green — matches status band behind notch).
const Color kHeroPaleGreen = Color(0xFFF0F7F0);

/// Legacy aliases (for gradual migration)
const Color kWellGreen = kPrimaryGreen;
const Color kNestOrange = kAccentOrange;

/// Legacy serif stack name (still in pubspec). Prefer [kFontHelveticaNow] for UI text.
const String kFontGeorgiaPro = 'GeorgiaPro';
const String kFontHelveticaNow = 'HelveticaNow';
const String kFontAppFamily = kFontHelveticaNow;

/// Line-height multiplier for legacy display text hooks (sans headlines).
const double kGeorgiaProLineHeightMultiplier = 1.22;

/// Horizontal squeeze for [GeorgiaProDisplaySquish] (narrower = more condensed).
const double kGeorgiaProDisplayScaleX = 0.93;

/// Vertical stretch paired with [kGeorgiaProDisplayScaleX] (taller letterforms).
const double kGeorgiaProDisplayScaleY = 1.07;

double _sansHeadlineLetterSpacing(double fontSize) => fontSize * (-18 / 1000);

/// Display / headline style (Helvetica Now). Kept name for existing call sites.
TextStyle georgiaProDisplayStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.bold,
  Color? color,
}) =>
    TextStyle(
      fontFamily: kFontHelveticaNow,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: _sansHeadlineLetterSpacing(fontSize),
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
  bottomAppBarTheme: BottomAppBarThemeData(
    elevation: 0,
    height: 56,
    padding: EdgeInsets.zero,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.06),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 2,
    highlightElevation: 4,
    backgroundColor: kAccentOrange,
    foregroundColor: Colors.white,
    shape: CircleBorder(),
    sizeConstraints: BoxConstraints.tightFor(width: 56, height: 56),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shadowColor: Colors.black.withValues(alpha: 0.08),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
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
  bottomAppBarTheme: BottomAppBarThemeData(
    elevation: 0,
    height: 56,
    padding: EdgeInsets.zero,
    color: const Color(0xFF1E1E1E),
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.black.withValues(alpha: 0.35),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 2,
    highlightElevation: 4,
    backgroundColor: kAccentOrange,
    foregroundColor: Colors.white,
    shape: CircleBorder(),
    sizeConstraints: BoxConstraints.tightFor(width: 56, height: 56),
  ),
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
  static const Color heroPaleGreen = kHeroPaleGreen;
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

/// Shared corner radii used by legacy and new widgets.
class AppRadii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

/// Soft scaffold washes for glass-friendly backgrounds.
class AppGradients {
  AppGradients._();

  static const LinearGradient softScaffold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0F4F1), Color(0xFFFAF9F6)],
  );

  /// Same vertical fade as [WellnestDiscoverHero]: pale green → blended → [surface].
  /// Discover uses [AppColors.backgroundCream]; recipe form uses white for field contrast.
  static LinearGradient discoverHeroFadeTo(Color surface) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.heroPaleGreen,
          AppColors.heroPaleGreen,
          Color.lerp(AppColors.heroPaleGreen, surface, 0.42) ?? surface,
          surface,
        ],
        stops: const [0.0, 0.42, 0.76, 1.0],
      );

  /// Blend stop shared with [discoverHeroFadeTo] — use for seams (hero → sheet).
  static Color discoverHeroBlendTowardSurface(Color surface) =>
      Color.lerp(AppColors.heroPaleGreen, surface, 0.42) ?? surface;

  /// Overlay on the hero image; tails match [discoverHeroFadeTo] so no pale line.
  static LinearGradient recipeDetailHeroImageBottomFade(Color surface) {
    final blend = discoverHeroBlendTowardSurface(surface);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.heroPaleGreen.withValues(alpha: 0),
        AppColors.heroPaleGreen.withValues(alpha: 0.16),
        blend.withValues(alpha: 0.52),
        blend.withValues(alpha: 0.88),
        surface.withValues(alpha: 0.94),
      ],
      stops: const [0.0, 0.3, 0.55, 0.82, 1.0],
    );
  }

  /// Strip under the hero; meets the scaffold gradient instead of flat hero green.
  static LinearGradient recipeDetailHeroToBodyCurve(Color surface) {
    final blend = discoverHeroBlendTowardSurface(surface);
    final towardSurface = Color.lerp(blend, surface, 0.55) ?? surface;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.heroPaleGreen.withValues(alpha: 0),
        blend.withValues(alpha: 0.72),
        towardSurface,
      ],
      stops: const [0.0, 0.58, 1.0],
    );
  }
}

/// Standardized curves
class AppCurves {
  static const Curve standard = Curves.easeInOut;
}

const double kMinTapTargetSize = 48.0;

/// Strong sans title style (Helvetica Now). Kept name for existing call sites.
TextStyle georgiaProTextStyle({
  double? fontSize,
  FontWeight fontWeight = FontWeight.bold,
  Color? color,
}) {
  final fs = fontSize;
  return TextStyle(
    fontFamily: kFontHelveticaNow,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: fs == null ? null : _sansHeadlineLetterSpacing(fs),
    height: 1.25,
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

/// Grey hairline stroke aligned with Discover search, cards, and bottom nav.
Color wellnestOutlineColor(BuildContext context) {
  final isLight = Theme.of(context).brightness == Brightness.light;
  return isLight
      ? const Color(0xFFC5C5C5).withValues(alpha: 0.95)
      : Colors.white.withValues(alpha: 0.18);
}

/// White (or [color]) surface with outline — no drop shadow (Discover / Feed branding).
BoxDecoration wellnestCardDecoration(
  BuildContext context, {
  double borderRadius = AppRadii.md,
  Color? color,
}) =>
    BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: wellnestOutlineColor(context), width: 1),
    );

/// In-column section titles (e.g. "Discover", "My Recipes").
TextStyle wellnestSectionTitleStyle({Color? color}) =>
    georgiaProTextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: color ?? kPrimaryGreen,
    ).copyWith(letterSpacing: 0);

/// Large tab titles (Feed, Saved, etc.) — normal tracking (not editorial squeeze).
TextStyle wellnestPageTitleStyle({Color? color}) =>
    georgiaProTextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: color ?? kPrimaryGreen,
    ).copyWith(letterSpacing: 0);
