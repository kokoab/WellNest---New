import 'package:flutter/material.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/georgia_pro_display_squish.dart';
import 'package:wellnest/widgets/terms_of_service_modal.dart';

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
  bool _agreedToTerms = false;

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
    final cs = theme.colorScheme;
    final labelColor = wellnestHeadingGreen(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Register',
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
          label: 'Back to login',
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: labelColor),
            onPressed: () => Navigator.pop(context),
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
                  const SizedBox(height: 10),
                  // Logo, re-use existing
                  SizedBox(
                    height: 80,
                    width: 80,
                    child: Image.asset(
                      'lib/assets/images/logo1.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GeorgiaProDisplaySquish(
                    alignment: Alignment.center,
                    child: Text(
                      'Create Account',
                      style: georgiaProTextStyle(
                        fontSize: 32,
                        color: labelColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Form Fields (labels left-aligned)
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildField(
                          context,
                          'Fullname:',
                          controller: _fullNameController,
                        ),
                        AppSpacing.gapV16,
                        _buildField(
                          context,
                          'Email:',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        AppSpacing.gapV16,
                        _buildField(
                          context,
                          'Password:',
                          controller: _passwordController,
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: _buildTermsAgreementRow(context, labelColor),
                  ),
                  AppSpacing.gapV24,
                  // Sign-up Button
                  SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? Center(
                            child:
                                CircularProgressIndicator(color: cs.primary),
                          )
                        : ElevatedButton(
                            onPressed: !_agreedToTerms
                                ? null
                                : () async {
                                    final fullName = _fullNameController.text
                                        .trim();
                                    final email = _emailController.text.trim();
                                    final password = _passwordController.text;
                                    if (fullName.isEmpty ||
                                        email.isEmpty ||
                                        password.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Fill in Fullname, Email and Password',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final parts =
                                        fullName.split(RegExp(r'\s+'));
                                    final firstName = parts.first;
                                    final lastName = parts.length > 1
                                        ? parts.sublist(1).join(' ')
                                        : '';
                                    setState(() => _isLoading = true);
                                    final error = await AuthService.instance
                                        .register(
                                      firstName: firstName,
                                      lastName: lastName,
                                      email: email,
                                      password: password,
                                      acceptedTerms: _agreedToTerms,
                                    );
                                    if (!context.mounted) return;
                                    setState(() => _isLoading = false);
                                    if (error != null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(error)),
                                      );
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/dashboard',
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.secondary,
                              foregroundColor: cs.onSecondary,
                              disabledBackgroundColor: cs
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              disabledForegroundColor: cs.onSurfaceVariant,
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
                            child: const Text('Sign Up'),
                          ),
                  ),
                  AppSpacing.gapV24,
                  // Connect: Navigate back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: wellnestCaptionColor(context),
                          fontFamily: 'HelveticaNow',
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: Text(
                          'Login',
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
    );
  }

  Widget _buildTermsAgreementRow(BuildContext context, Color labelColor) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      color: labelColor,
      fontFamily: 'HelveticaNow',
      fontSize: 15,
      height: 1.35,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: _agreedToTerms,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return cs.primary;
                }
                return null;
              }),
              checkColor: cs.onPrimary,
              side: BorderSide(color: labelColor.withValues(alpha: 0.85)),
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 0,
                  children: [
                    Text('I agree to the ', style: baseStyle),
                    GestureDetector(
                      onTap: () => TermsOfServiceModal.show(context),
                      child: Text(
                        'Terms & Conditions',
                        style: baseStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: labelColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!_agreedToTerms)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Please read and accept the Terms & Conditions to create an account.',
              style: TextStyle(
                color: wellnestCaptionColor(context),
                fontFamily: 'HelveticaNow',
                fontSize: 13,
              ),
              textAlign: TextAlign.left,
            ),
          ),
      ],
    );
  }

  Widget _buildField(
    BuildContext context,
    String label, {
    bool obscureText = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
  }) {
    final cs = Theme.of(context).colorScheme;
    final labelColor = wellnestHeadingGreen(context);

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
        AppSpacing.gapV8,
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
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
            hintText: label == 'Fullname:'
                ? 'Your full name'
                : label == 'Email:'
                    ? 'Your email'
                    : 'Your password',
            hintStyle: TextStyle(
              fontFamily: 'HelveticaNow',
              color: wellnestCaptionColor(context),
            ),
          ),
        ),
      ],
    );
  }
}
