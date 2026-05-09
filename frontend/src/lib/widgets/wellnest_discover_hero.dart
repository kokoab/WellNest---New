import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';
import 'package:my_app/widgets/wellnest_header.dart';

/// Pale-green hero with rounded bottom — fills behind the status bar; content is inset.
class WellnestDiscoverHero extends StatelessWidget {
  final Widget searchSlot;

  const WellnestDiscoverHero({super.key, required this.searchSlot});

  static const double _greetingFontSize = 20;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.heroPaleGreen,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          topInset + AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WellnestHeader(),
            AppSpacing.gapV12,
            GeorgiaProDisplaySquish(
              child: Text(
                'What are we cooking today?',
                style: georgiaProTextStyle(
                  fontSize: _greetingFontSize,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            AppSpacing.gapV16,
            searchSlot,
          ],
        ),
      ),
    );
  }
}
