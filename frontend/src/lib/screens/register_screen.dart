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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Register',
          style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        leading: Semantics(
          button: true,
          label: 'Back to login',
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppSpacing.gapV16,
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: Image.asset(
                      'lib/assets/images/logo1.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  AppSpacing.gapV8,
                  Text(
                    'Create Account',
                    style: textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapV8,
                  Text(
                    'Join the Wellnest community with the same warm, familiar theme.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField(
                          context,
                          'Full name',
                          controller: _fullNameController,
                        ),
                        AppSpacing.gapV16,
                        _buildField(
                          context,
                          'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        AppSpacing.gapV16,
                        _buildField(
                          context,
                          'Password',
                          controller: _passwordController,
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapV24,
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: CircularProgressIndicator(color: kPrimaryGreen),
                            ),
                          )
                        : FilledButton(
                            onPressed: () async {
                              final fullName = _fullNameController.text.trim();
                              final email = _emailController.text.trim();
                              final password = _passwordController.text;
                              if (fullName.isEmpty ||
                                  email.isEmpty ||
                                  password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Fill in Full name, Email and Password',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final parts = fullName.split(RegExp(r'\s+'));
                              final firstName = parts.first;
                              final lastName =
                                  parts.length > 1 ? parts.sublist(1).join(' ') : '';
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
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.secondary,
                              foregroundColor: colorScheme.onSecondary,
                            ),
                            child: const Text('Sign Up'),
                          ),
                  ),
                  AppSpacing.gapV16,
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                  AppSpacing.gapV24,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label, {
    bool obscureText = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        AppSpacing.gapV8,
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: label == 'Full name'
                ? 'Your full name'
                : label == 'Email'
                ? 'Your email'
                : 'Your password',
          ),
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}