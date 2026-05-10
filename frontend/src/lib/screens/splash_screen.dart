import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';

class WellnestSplashScreen extends StatelessWidget {
  const WellnestSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heading = wellnestHeadingGreen(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentW = math.min(
              constraints.maxWidth,
              AppSpacing.authFormMaxWidth,
            );
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentW,
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),
                      Semantics(
                        label: 'Wellnest logo',
                        image: true,
                        child: Image.asset(
                          'lib/assets/images/logo1.png',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GeorgiaProDisplaySquish(
                        alignment: Alignment.center,
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: georgiaProDisplayStyle(fontSize: 40),
                            children: [
                              TextSpan(
                                text: 'well',
                                style: TextStyle(color: heading),
                              ),
                              TextSpan(
                                text: 'nest',
                                style: TextStyle(color: cs.secondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A Free healthy Recipe Mobile App\nfor Everyday Wellness',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: wellnestCaptionColor(context),
                          height: 1.4,
                        ),
                      ),
                      const Spacer(flex: 2),
                      Semantics(
                        button: true,
                        label: 'Sign up for a new account',
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.secondary,
                              foregroundColor: cs.onSecondary,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'HelveticaNow',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            child: const Text('Sign Up'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        button: true,
                        label: 'Log in to your account',
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'HelveticaNow',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            child: const Text('Log In'),
                          ),
                        ),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}