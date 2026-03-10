import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color wellGreen = kPrimaryGreen;
    const Color nestOrange = kAccentOrange;

    return Scaffold(
      backgroundColor: kBackgroundCream,
      appBar: AppBar(
        title: const Text("Login", style: TextStyle(fontSize: 16, color: kPrimaryGreen)),
        backgroundColor: kBackgroundCream,
        elevation: 0,
        foregroundColor: kPrimaryGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryGreen),
          onPressed: () {
            // Navigate back to the Splash/Welcome screen
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo placeholder, re-use existing
              Container(
                height: 100,
                width: 100,
                child: Image.asset(
                  'lib/assets/images/logo1.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Log In',
                style: TextStyle(
                  fontFamily: 'Recoleta',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryGreen,
                ),
              ),
              const SizedBox(height: 40),
              // Form fields (labels left-aligned)
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Email:",
                      style: TextStyle(
                        color: wellGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.gapV8,
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        hintText: 'Enter your email',
                        hintStyle: TextStyle(fontFamily: 'HelveticaNow', color: Colors.grey.shade600),
                      ),
                    ),
                    AppSpacing.gapV16,
                    const Text(
                      "Password:",
                      style: TextStyle(
                        color: wellGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.gapV8,
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        hintText: 'Enter your password',
                        hintStyle: TextStyle(fontFamily: 'HelveticaNow', color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapV24,
              // Enter Button
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
                    : ElevatedButton(
                        onPressed: () async {
                          final email = _emailController.text.trim();
                          final password = _passwordController.text;
                          if (email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter email and password')),
                            );
                            return;
                          }
                          setState(() => _isLoading = true);
                          final error = await AuthService.instance.login(email, password);
                          if (!mounted) return;
                          setState(() => _isLoading = false);
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                            return;
                          }
                          Navigator.pushReplacementNamed(context, '/dashboard');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: nestOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontFamily: 'HelveticaNow', fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        child: const Text('Enter'),
                      ),
              ),
              AppSpacing.gapV24,
              // Connect: Navigate to Register page
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: wellGreen, fontFamily: 'HelveticaNow'),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Text(
                      "Signup",
                      style: TextStyle(
                        color: wellGreen,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'HelveticaNow',
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
}