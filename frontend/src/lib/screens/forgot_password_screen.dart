import 'package:flutter/material.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _message;
  bool _codeSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Enter your email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = null;
    });

    final result = await AuthService.instance.requestPasswordReset(email);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _message = result;
      _codeSent = result != null;
    });
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty ||
        code.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      setState(() => _message = 'Fill in the code and both password fields.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _message = 'Passwords do not match.');
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
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundCream,
      appBar: AppBar(
        title: const Text(
          'Forgot Password',
          style: TextStyle(fontSize: 16, color: kPrimaryGreen),
        ),
        backgroundColor: kBackgroundCream,
        elevation: 0,
        foregroundColor: kPrimaryGreen,
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
                  'Reset your password',
                  style: georgiaProTextStyle(
                    fontSize: 30,
                    color: kPrimaryGreen,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We will send a reset code to the address on file.',
                style: TextStyle(
                  color: kPrimaryGreen.withValues(alpha: 0.8),
                  fontFamily: 'HelveticaNow',
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapV24,
              Semantics(
                textField: true,
                label: 'Email',
                hint: 'Enter your email',
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
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
                      color: Colors.grey.shade600,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: kPrimaryGreen,
                      fontFamily: 'HelveticaNow',
                    ),
                  ),
                ),
              AppSpacing.gapV24,
              if (_codeSent) ...[
                Semantics(
                  textField: true,
                  label: 'Reset code',
                  hint: 'Enter the code from your email',
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      hintText: '6-digit code',
                      hintStyle: TextStyle(
                        fontFamily: 'HelveticaNow',
                        color: Colors.grey.shade600,
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
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
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
                        color: Colors.grey.shade600,
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
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
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
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                AppSpacing.gapV24,
                SizedBox(
                  width: double.infinity,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryGreen,
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kAccentOrange,
                            foregroundColor: Colors.white,
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
                AppSpacing.gapV16,
              ],
              SizedBox(
                width: double.infinity,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: kPrimaryGreen),
                      )
                    : ElevatedButton(
                        onPressed: _codeSent ? null : _sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentOrange,
                          foregroundColor: Colors.white,
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
                        child: Text(
                          _codeSent ? 'Code sent' : 'Send reset code',
                        ),
                      ),
              ),
              AppSpacing.gapV24,
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
