import 'package:flutter/material.dart';
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
              Image.asset(
                'lib/assets/images/logo1.png',
                height: 140,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Recoleta',
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(text: 'well', style: TextStyle(color: kPrimaryGreen)),
                    TextSpan(text: 'nest', style: TextStyle(color: kAccentOrange)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A Free healthy Recipe Mobile App\nfor Everyday Wellness',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: kPrimaryGreen.withValues(alpha: 0.9), height: 1.4),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontFamily: 'HelveticaNow', fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  child: const Text('Sign Up'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontFamily: 'HelveticaNow', fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  child: const Text('Log In'),
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