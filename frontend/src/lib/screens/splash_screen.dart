import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/theme/app_theme.dart';

class WellnestSplashScreen extends StatelessWidget {
  const WellnestSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundCream,
      body: SafeArea(
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
              RichText(
                text: TextSpan(
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.55,
                    height: 1.05,
                  ),
                  children: const [
                    TextSpan(text: 'well', style: TextStyle(color: kPrimaryGreen)),
                    TextSpan(text: 'nest', style: TextStyle(color: kAccentOrange)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A Free healthy Recipe Mobile App\nfor Everyday Wellness',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: kPrimaryGreen.withValues(alpha: 0.88),
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 2),
              Semantics(
                button: true,
                label: 'Sign up for a new account',
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentOrange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: GoogleFonts.plusJakartaSans(
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
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: GoogleFonts.plusJakartaSans(
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
  }
}