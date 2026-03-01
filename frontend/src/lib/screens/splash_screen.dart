import 'package:flutter/material.dart';

class WellnestSplashScreen extends StatelessWidget {
  const WellnestSplashScreen({super.key});

  // Your Brand Colors
  static const Color wellGreen = Color(0xFF097333); 
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color buttonYellow = Color(0xFFFDB813);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey from image
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              
              // Logo Asset
              Image.asset(
                'lib/assets/images/logo1.png', 
                height: 160,
                fit: BoxFit.contain,
              ),
              
              const SizedBox(height: 20),
              
              // App Name with split colors
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.0,
                  ),
                  children: [
                    TextSpan(text: 'well', style: TextStyle(color: wellGreen)),
                    TextSpan(text: 'nest', style: TextStyle(color: nestOrange)),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Tagline
              const Text(
                'A Free healthy Recipe Mobile App\nfor Everyday Wellness',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: wellGreen,
                  height: 1.4,
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Get Started Button
              OutlinedButton(
                onPressed: () {
                  // NAVIGATION: Move to Login Screen
                  Navigator.pushNamed(context, '/login');
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: wellGreen, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                    color: buttonYellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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