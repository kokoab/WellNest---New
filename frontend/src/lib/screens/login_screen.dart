import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';

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
    const Color wellGreen = Color(0xFF097333);
    const Color nestOrange = Color(0xFFEF5026);
    const Color accentYellow = Color(0xFFFDB813);

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          "LoginForm",
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurfaceVariant),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              // App Name with split colors and custom Recoleta font if you set it up
              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 48,
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
              const SizedBox(height: 48),
              // Username Field
              const Text(
                "Email:",
                style: TextStyle(
                  color: wellGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: accentYellow),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: accentYellow),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Password Field
              const Text(
                "Password:",
                style: TextStyle(
                  color: wellGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: accentYellow),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: accentYellow),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Enter Button
              Align(
                alignment: Alignment.centerRight,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFF097333))
                    : OutlinedButton(
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
                          'Enter',
                          style: TextStyle(
                            color: accentYellow,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              // Connect: Navigate to Register page
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Dont have an account? ",
                    style: TextStyle(color: wellGreen),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate to Register
                      Navigator.pushNamed(context, '/register');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF097333)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        "Signup",
                        style: TextStyle(
                          color: accentYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              // Admin Login Button
              Center(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin_login');
                  },
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF097333), width: 1.2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Admin Login',
                    style: TextStyle(
                      color: accentYellow,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}