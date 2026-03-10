import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
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
        title: const Text("Register", style: TextStyle(fontSize: 16, color: kPrimaryGreen)),
        backgroundColor: kBackgroundCream,
        elevation: 0,
        foregroundColor: kPrimaryGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kPrimaryGreen),
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
              const Text(
                'Create Account',
                style: TextStyle(
                  fontFamily: 'Recoleta',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryGreen,
                ),
              ),
              const SizedBox(height: 32),
              // Form Fields (labels left-aligned)
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField("Fullname:", controller: _fullNameController),
                    AppSpacing.gapV16,
                    _buildField("Email:", controller: _emailController, keyboardType: TextInputType.emailAddress),
                    AppSpacing.gapV16,
                    _buildField("Password:", controller: _passwordController, obscureText: true),
                  ],
                ),
              ),
              AppSpacing.gapV24,
              // Sign-up Button
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
                    : ElevatedButton(
                        onPressed: () async {
                          final fullName = _fullNameController.text.trim();
                          final email = _emailController.text.trim();
                          final password = _passwordController.text;
                          if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Fill in Fullname, Email and Password')),
                            );
                            return;
                          }
                          final parts = fullName.split(RegExp(r'\s+'));
                          final firstName = parts.first;
                          final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                          setState(() => _isLoading = true);
                          final error = await AuthService.instance.register(
                            firstName: firstName,
                            lastName: lastName,
                            email: email,
                            password: password,
                          );
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
                  child: const Text('Sign Up'),
                ),
              ),
              AppSpacing.gapV24,
              // Connect: Navigate back to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(color: wellGreen, fontFamily: 'HelveticaNow'),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      "Login",
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

  Widget _buildField(String label,
      {bool obscureText = false, TextEditingController? controller, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: kPrimaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.gapV8,
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: label == 'Fullname:' ? 'Your full name' : label == 'Email:' ? 'Your email' : 'Your password',
            hintStyle: TextStyle(fontFamily: 'HelveticaNow', color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}