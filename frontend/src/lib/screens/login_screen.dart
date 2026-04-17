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

  Future<void> _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);
    final result = await AuthService.instance.login(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Login failed')),
      );
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      result.isAdmin ? '/admin_dashboard' : '/dashboard',
    );
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
          "Login",
          style: textTheme.titleMedium?.copyWith(
            fontFamily: kFontAppFamily,
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        leading: Semantics(
          button: true,
          label: 'Back',
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
                  AppSpacing.gapV24,
                  SizedBox(
                    height: 100,
                    width: 100,
                    child: Image.asset(
                      'lib/assets/images/logo1.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  AppSpacing.gapV12,
                  Text(
                    'Log In',
                    style: textTheme.displayMedium,
                  ),
                  AppSpacing.gapV8,
                  Text(
                    'Welcome back to Wellnest.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email',
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        AppSpacing.gapV8,
                        Semantics(
                          textField: true,
                          label: 'Email',
                          hint: 'Enter your email',
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              hintText: 'Enter your email',
                            ),
                            style: textTheme.bodyLarge,
                          ),
                        ),
                        AppSpacing.gapV16,
                        Text(
                          'Password',
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                          ),
                        ),
                        AppSpacing.gapV8,
                        Semantics(
                          textField: true,
                          label: 'Password',
                          hint: 'Enter your password',
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_isLoading) _submitLogin();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Enter your password',
                            ),
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapV24,
                  Semantics(
                    button: true,
                    label: 'Log in',
                    enabled: !_isLoading,
                    child: SizedBox(
                      width: double.infinity,
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: kPrimaryGreen,
                                ),
                              ),
                            )
                          : FilledButton(
                              onPressed: _submitLogin,
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: colorScheme.onSecondary,
                              ),
                              child: const Text('Enter'),
                            ),
                    ),
                  ),
                  AppSpacing.gapV16,
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/register'),
                        child: const Text('Signup'),
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
}