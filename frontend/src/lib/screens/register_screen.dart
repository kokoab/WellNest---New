import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color wellGreen = Color(0xFF097333);
    const Color nestOrange = Color(0xFFEF5026);
    const Color accentYellow = Color(0xFFFDB813);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Register Form",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () {
            // Navigate back to Login
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              // Logo, re-use existing
              Container(
                height: 80,
                width: 80,
                child: Image.asset(
                  'lib/assets/images/logo1.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              // App Name with split colors
              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 36,
                      // Uncomment if you setup the font
                      // fontFamily: 'Recoleta',
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(text: 'well', style: TextStyle(color: wellGreen)),
                      TextSpan(
                          text: 'nest', style: TextStyle(color: nestOrange)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Form Fields (Fullname, Email, Username, Password)
              _buildField("Fullname:", wellGreen, accentYellow),
              const SizedBox(height: 20),
              _buildField("Email:", wellGreen, accentYellow),
              const SizedBox(height: 20),
              _buildField("Username:", wellGreen, accentYellow),
              const SizedBox(height: 20),
              _buildField("Password:", wellGreen, accentYellow, obscureText: true),
              const SizedBox(height: 32),
              // Sign-up Button
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () {
                    // Navigate to content or login
                  },
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF097333), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Sign-up',
                    style: TextStyle(
                      color: accentYellow,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Connect: Navigate back to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Dont have an account? ",
                    style: TextStyle(color: wellGreen),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate back to Login
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF097333)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: accentYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, Color labelColor, Color borderColor, {bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          obscureText: obscureText,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }
}