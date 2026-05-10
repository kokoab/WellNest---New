import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/screens/splash_screen.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  /// Splash may be under this route, or the stack may be only `/login` (e.g. after logout).
  void _exitToSplashOrPop() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(
        builder: (_) => const WellnestSplashScreen(),
      ),
      (route) => false,
    );
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error ?? 'Login failed')));
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
    final cs = theme.colorScheme;
    final labelColor = wellnestHeadingGreen(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _exitToSplashOrPop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Login',
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              color: labelColor,
            ),
          ),
          backgroundColor: cs.surface,
          elevation: 0,
          foregroundColor: cs.onSurface,
          surfaceTintColor: Colors.transparent,
          leading: Semantics(
            button: true,
            label: 'Back',
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: labelColor),
              onPressed: _exitToSplashOrPop,
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.authFormMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo placeholder, re-use existing
              SizedBox(
                height: 100,
                width: 100,
                child: Image.asset(
                  'lib/assets/images/logo1.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 12),
              GeorgiaProDisplaySquish(
                alignment: Alignment.center,
                child: Text(
                  'Log In',
                  style: georgiaProTextStyle(
                    fontSize: 32,
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Form fields (labels left-aligned)
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email:',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cs.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          hintText: 'Enter your email',
                          hintStyle: TextStyle(
                            fontFamily: 'HelveticaNow',
                            color: wellnestCaptionColor(context),
                          ),
                        ),
                        style: TextStyle(color: cs.onSurface),
                      ),
                    ),
                    AppSpacing.gapV16,
                    Text(
                      'Password:',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cs.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(
                            fontFamily: 'HelveticaNow',
                            color: wellnestCaptionColor(context),
                          ),
                        ),
                        style: TextStyle(color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapV24,
              // Enter Button
              Semantics(
                button: true,
                label: 'Log in',
                enabled: !_isLoading,
                child: SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: cs.primary,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _submitLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.secondary,
                            foregroundColor: cs.onSecondary,
                            minimumSize: const Size(double.infinity, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'HelveticaNow',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          child: const Text('Enter'),
                        ),
                ),
              ),
              AppSpacing.gapV12,
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.secondary,
                    textStyle: const TextStyle(
                      fontFamily: 'HelveticaNow',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              AppSpacing.gapV16,
              // Connect: Navigate to Register page
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: wellnestCaptionColor(context),
                      fontFamily: 'HelveticaNow',
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/register'),
                    child: Text(
                      'Signup',
                      style: TextStyle(
                        color: labelColor,
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
          ),
        ),
      ),
    );
  }
}
