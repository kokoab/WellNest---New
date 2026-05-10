import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _message;

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => _message = 'Fill in every field.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final result = await AuthService.instance.resetPassword(
      code: code,
      email: email,
      password: password,
      passwordConfirmation: confirmPassword,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = result;
    });

    if (result != null && result.toLowerCase().contains('success')) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      Navigator.popUntil(context, ModalRoute.withName('/login'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labelColor = wellnestHeadingGreen(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Reset Password',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            color: labelColor,
          ),
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              GeorgiaProDisplaySquish(
                alignment: Alignment.center,
                child: Text(
                  'Set a new password',
                  style: georgiaProTextStyle(
                    fontSize: 30,
                    color: labelColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code sent to your email address.',
                style: TextStyle(
                  color: wellnestCaptionColor(context),
                  fontFamily: 'HelveticaNow',
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapV24,
              Semantics(
                textField: true,
                label: 'Reset code',
                hint: 'Enter the 6-digit code',
                child: TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: cs.onSurface),
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
                    hintText: '000000',
                    hintStyle: TextStyle(
                      fontFamily: 'HelveticaNow',
                      color: wellnestCaptionColor(context),
                    ),
                  ),
                ),
              ),
              AppSpacing.gapV16,
              Semantics(
                textField: true,
                label: 'Email',
                hint: 'Enter your registered email',
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: cs.onSurface),
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
                    hintText: 'Registered email',
                    hintStyle: TextStyle(
                      fontFamily: 'HelveticaNow',
                      color: wellnestCaptionColor(context),
                    ),
                  ),
                ),
              ),
              AppSpacing.gapV16,
              Semantics(
                textField: true,
                label: 'New password',
                hint: 'Enter your new password',
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: cs.onSurface),
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
                    hintText: 'New password',
                    hintStyle: TextStyle(
                      fontFamily: 'HelveticaNow',
                      color: wellnestCaptionColor(context),
                    ),
                  ),
                ),
              ),
              AppSpacing.gapV16,
              Semantics(
                textField: true,
                label: 'Confirm password',
                hint: 'Confirm your new password',
                child: TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: TextStyle(color: cs.onSurface),
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
                    hintText: 'Confirm password',
                    hintStyle: TextStyle(
                      fontFamily: 'HelveticaNow',
                      color: wellnestCaptionColor(context),
                    ),
                  ),
                ),
              ),
              AppSpacing.gapV16,
              if (_message != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontFamily: 'HelveticaNow',
                    ),
                  ),
                ),
              AppSpacing.gapV24,
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: cs.primary),
                      )
                    : ElevatedButton(
                        onPressed: _resetPassword,
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
                        child: const Text('Reset password'),
                      ),
              ),
              AppSpacing.gapV24,
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: cs.secondary),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
