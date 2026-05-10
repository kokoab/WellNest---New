import 'package:flutter/material.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/theme/app_spacing.dart';

/// Field styling aligned with [RecipeFormScreen] / cook-mode review modal.
const Color _formFieldFill = Color(0xFFF3F4F6);
const Color _formFieldBorder = Color(0xFFBDBDBD);

/// Edit Profile Overlay for user profile page.
/// Allows users to change Name and Email.
class EditProfileOverlay extends StatefulWidget {
  final CurrentUser user;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;

  const EditProfileOverlay({
    super.key,
    required this.user,
    this.onSaved,
    this.onCancel,
  });

  @override
  State<EditProfileOverlay> createState() => _EditProfileOverlayState();
}

class _EditProfileOverlayState extends State<EditProfileOverlay> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;

  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(10);
    final side = const BorderSide(color: _formFieldBorder, width: 1);
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _formFieldFill,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: side),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.user.firstName);
    _lastNameController = TextEditingController(text: widget.user.lastName);
    _emailController = TextEditingController(text: widget.user.email);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (password.isNotEmpty) {
      if (password.length < 8) {
        setState(() {
          _error = 'Password must be at least 8 characters.';
        });
        return;
      }
      if (password != confirmPassword) {
        setState(() {
          _error = 'Password and confirmation do not match.';
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await UserService.instance.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: password.isEmpty ? null : password,
      );

      if (mounted) {
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.discoverHeroFadeTo(Colors.white),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.edit_outlined, color: kPrimaryGreen, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Edit Profile',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: kFontHelveticaNow,
                            color: kPrimaryGreen,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () {
                          widget.onCancel?.call();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.close, color: cs.onSurfaceVariant, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update your account details and password.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFamily: kFontHelveticaNow,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: kAccentOrange.withValues(alpha: 0.1),
                        border: Border.all(color: kAccentOrange),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: kAccentOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: kAccentOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _firstNameController,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'First Name',
                      prefixIcon: const Icon(Icons.person_outline, size: 22),
                    ),
                    style: TextStyle(
                      fontFamily: kFontHelveticaNow,
                      color: cs.onSurface,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _lastNameController,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Last Name',
                      prefixIcon: const Icon(Icons.person_outline, size: 22),
                    ),
                    style: TextStyle(
                      fontFamily: kFontHelveticaNow,
                      color: cs.onSurface,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _emailController,
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined, size: 22),
                    ),
                    style: TextStyle(
                      fontFamily: kFontHelveticaNow,
                      color: cs.onSurface,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Change Password (optional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: kFontHelveticaNow,
                      color: kPrimaryGreen,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(
                      fontFamily: kFontHelveticaNow,
                      color: cs.onSurface,
                    ),
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 22),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(
                      fontFamily: kFontHelveticaNow,
                      color: cs.onSurface,
                    ),
                    decoration: _fieldDecoration(
                      context,
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_reset_outlined, size: 22),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                widget.onCancel?.call();
                                Navigator.of(context).pop();
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: kPrimaryGreen,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: kFontHelveticaNow,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: kPrimaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontFamily: kFontHelveticaNow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Show the edit profile overlay.
Future<void> showEditProfileOverlay(
  BuildContext context,
  CurrentUser user, {
  VoidCallback? onSaved,
}) {
  return showDialog(
    context: context,
    builder: (context) => EditProfileOverlay(
      user: user,
      onSaved: onSaved,
    ),
  );
}
