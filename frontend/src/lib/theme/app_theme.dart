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

/// Bundled WellNest Assistant mark (same image as `storage/profile-photos/logo.jpg` on the API).
const String kWellnestAssistantLogoAsset =
    'lib/assets/images/wellnest_assistant_logo.jpg';

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

/// Dark surfaces — green-gray harmony with [kPrimaryGreen]; avoid harsh pure blacks.
const Color kDarkScaffold = Color(0xFF161F1B);
const Color kDarkSurface = Color(0xFF1E2A25);
const Color kDarkSurfaceContainer = Color(0xFF2C3D35);
const Color kDarkSurfaceContainerHigh = Color(0xFF253830);
const Color kDarkSurfaceContainerMid = Color(0xFF213028);

/// Brand-tinted mint for headings on dark backgrounds (readable vs raw [kPrimaryGreen]).
const Color kDarkHeadingGreen = Color(0xFF82DCB0);

/// Dark theme — mirrors [lightTheme] structure so components resolve colors from [ThemeData].
ThemeData get darkTheme {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.dark,
    primary: kPrimaryGreen,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF133528),
    onPrimaryContainer: const Color(0xFFC8F5DD),
    secondary: kAccentOrange,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF6B2E1A),
    onSecondaryContainer: const Color(0xFFFFE0D9),
    surface: kDarkSurface,
    onSurface: const Color(0xFFE8EDE9),
    onSurfaceVariant: const Color(0xFFB0C4BB),
    outline: const Color(0xFF5C6B64),
    outlineVariant: const Color(0xFF3D4A44),
  ).copyWith(
    surfaceContainerHighest: kDarkSurfaceContainer,
    surfaceContainerHigh: kDarkSurfaceContainerHigh,
    surfaceContainer: kDarkSurfaceContainerMid,
  );

  final headlineGreen = kDarkHeadingGreen;

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: kFontHelveticaNow,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kDarkScaffold,
    cardColor: kDarkSurfaceContainer,
    canvasColor: kDarkScaffold,
    dividerColor: const Color(0xFF3D4A44).withValues(alpha: 0.85),
    bottomAppBarTheme: BottomAppBarThemeData(
      elevation: 0,
      height: 56,
      padding: EdgeInsets.zero,
      color: kDarkSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0xFF0A100D).withValues(alpha: 0.45),
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
      backgroundColor: kDarkSurface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      titleTextStyle: georgiaProDisplayStyle(
        fontSize: 20,
        color: colorScheme.onSurface,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: georgiaProDisplayStyle(fontSize: 32, color: headlineGreen),
      headlineMedium: georgiaProDisplayStyle(fontSize: 28, color: headlineGreen),
      titleLarge: georgiaProDisplayStyle(fontSize: 18, color: headlineGreen),
      titleMedium: georgiaProDisplayStyle(fontSize: 18, color: headlineGreen),
      bodyLarge: TextStyle(
        fontFamily: kFontHelveticaNow,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: colorScheme.onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: kFontHelveticaNow,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: colorScheme.onSurface,
      ),
      labelSmall: TextStyle(
        fontFamily: kFontHelveticaNow,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: kDarkSurfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shadowColor: const Color(0xFF0A100D).withValues(alpha: 0.5),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
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
      fillColor: colorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: TextStyle(
        color: headlineGreen.withValues(alpha: 0.65),
        fontSize: 16,
      ),
    ),
    focusColor: kPrimaryGreen,
    highlightColor: kPrimaryGreen.withValues(alpha: 0.28),
  );
}

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

  /// Discover top hero — light uses pale green wash; dark uses a deep green-tinted blend to scaffold.
  static LinearGradient discoverHeroFor(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.scaffoldBackgroundColor;
    if (theme.brightness == Brightness.light) {
      return discoverHeroFadeTo(surface);
    }
    final cs = theme.colorScheme;
    final top = Color.lerp(cs.primaryContainer, surface, 0.12) ?? cs.surface;
    final mid =
        Color.lerp(top, surface, 0.55) ?? surface;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        top,
        top,
        mid,
        surface,
      ],
      stops: const [0.0, 0.42, 0.76, 1.0],
    );
  }

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
  final cs = Theme.of(context).colorScheme;
  final isLight = Theme.of(context).brightness == Brightness.light;
  return isLight
      ? const Color(0xFFC5C5C5).withValues(alpha: 0.95)
      : cs.outline.withValues(alpha: 0.65);
}

/// Card / elevated strip surface from theme (light: white card; dark: elevated container).
Color wellnestCardSurface(BuildContext context) {
  final t = Theme.of(context);
  return t.cardTheme.color ?? t.colorScheme.surface;
}

/// Section headlines — brand green in light; lighter green on dark for contrast.
Color wellnestHeadingGreen(BuildContext context) {
  return Theme.of(context).brightness == Brightness.light
      ? kPrimaryGreen
      : kDarkHeadingGreen;
}

/// Muted body / caption line that tracks theme (replaces fixed [kCaptionGray] in new code).
Color wellnestCaptionColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// White (or [color]) surface with outline — no drop shadow (Discover / Feed branding).
BoxDecoration wellnestCardDecoration(
  BuildContext context, {
  double borderRadius = AppRadii.md,
  Color? color,
}) =>
    BoxDecoration(
      color: color ?? wellnestCardSurface(context),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: wellnestOutlineColor(context), width: 1),
    );

/// Full-bleed strip (feed posts / composer): themed surface with grey rules on
/// [top] and/or [bottom] only — no left/right stroke so the card reaches screen edges.
BoxDecoration wellnestFeedStripDecoration(
  BuildContext context, {
  Color? color,
  bool top = true,
  bool bottom = true,
}) =>
    BoxDecoration(
      color: color ?? wellnestCardSurface(context),
      border: Border(
        top: top
            ? BorderSide(color: wellnestOutlineColor(context), width: 1)
            : BorderSide.none,
        bottom: bottom
            ? BorderSide(color: wellnestOutlineColor(context), width: 1)
            : BorderSide.none,
      ),
    );

/// In-column section titles (e.g. "Discover", "My Recipes").
TextStyle wellnestSectionTitleStyle({Color? color}) =>
    georgiaProTextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: color ?? kPrimaryGreen,
    ).copyWith(letterSpacing: 0);

/// Prefer this at call sites so dark mode picks a readable heading color.
TextStyle wellnestSectionTitleStyleFor(BuildContext context) =>
    wellnestSectionTitleStyle(color: wellnestHeadingGreen(context));

/// Large tab titles (Feed, Saved, etc.) — normal tracking (not editorial squeeze).
TextStyle wellnestPageTitleStyle({Color? color}) =>
    georgiaProTextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: color ?? kPrimaryGreen,
    ).copyWith(letterSpacing: 0);

TextStyle wellnestPageTitleStyleFor(BuildContext context) =>
    wellnestPageTitleStyle(color: wellnestHeadingGreen(context));
