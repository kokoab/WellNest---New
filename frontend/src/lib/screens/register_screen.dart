import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';

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
    const Color wellGreen = Color(0xFF097333);
    const Color nestOrange = Color(0xFFEF5026);
    const Color accentYellow = Color(0xFFFDB813);

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "Register Form",
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
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
              // Form Fields (Fullname, Email, Password — backend uses first_name, last_name, email, password)
              _buildField("Fullname:", wellGreen, accentYellow, controller: _fullNameController),
              const SizedBox(height: 20),
              _buildField("Email:", wellGreen, accentYellow, controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 20),
              _buildField("Password:", wellGreen, accentYellow, controller: _passwordController, obscureText: true),
              const SizedBox(height: 32),
              // Sign-up Button
              Align(
                alignment: Alignment.centerRight,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF097333))
                    : OutlinedButton(
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
                    "Already have an account? ",
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

  Widget _buildField(String label, Color labelColor, Color borderColor,
      {bool obscureText = false, TextEditingController? controller, TextInputType? keyboardType}) {
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
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
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