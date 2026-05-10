import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/wellnest_header.dart';

/// Pale-green hero with rounded bottom — fills behind the status bar; content is inset.
class WellnestDiscoverHero extends StatefulWidget {
  final Widget searchSlot;

  const WellnestDiscoverHero({super.key, required this.searchSlot});

  @override
  State<WellnestDiscoverHero> createState() => _WellnestDiscoverHeroState();
}

class _WellnestDiscoverHeroState extends State<WellnestDiscoverHero>
    with WidgetsBindingObserver {
  static const double _avatarRadius = 24;
  Color _avatarBorderColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFC5C5C5).withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.22);

  CurrentUser? _user;
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    if (!AuthService.instance.isLoggedIn) {
      if (mounted) {
        setState(() {
          _user = null;
          _loadingUser = false;
        });
      }
      return;
    }
    final user = await UserService.instance.fetchCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
      _loadingUser = false;
    });
  }

  String _timeOfDayLine() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _greetingName() {
    final raw = _user?.firstName.trim() ?? '';
    if (raw.isNotEmpty) return raw;
    return 'there';
  }

  String _initials() {
    if (_user == null) return '?';
    final first = _user!.firstName.isNotEmpty ? _user!.firstName[0] : '';
    final last = _user!.lastName.isNotEmpty ? _user!.lastName[0] : '';
    final s = '${first.toUpperCase()}${last.toUpperCase()}'.trim();
    return s.isNotEmpty ? s : '?';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        statusBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppGradients.discoverHeroFor(context),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          topInset + AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hey, ${_greetingName()} 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: kFontAppFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _timeOfDayLine(),
                              style: TextStyle(
                                fontFamily: kFontAppFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                                color: wellnestCaptionColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const WellnestHeaderActions(wrapWithFlexible: false),
              ],
            ),
            AppSpacing.gapV16,
            widget.searchSlot,
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    late final Widget inner;
    if (_loadingUser) {
      inner = CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryGreen,
          ),
        ),
      );
    } else {
      final photoUrl = _user?.displayProfilePhotoUrl;
      inner = CircleAvatar(
        radius: _avatarRadius,
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFFFEECC)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: photoUrl != null && photoUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  photoUrl,
                  width: _avatarRadius * 2,
                  height: _avatarRadius * 2,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  cacheWidth: 192,
                  errorBuilder: (context, error, stackTrace) =>
                      _initialsAvatar(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    );
                  },
                ),
              )
            : _initialsAvatar(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _avatarBorderColor(context), width: 1),
      ),
      child: inner,
    );
  }

  Widget _initialsAvatar() {
    final cs = Theme.of(context).colorScheme;
    return Text(
      _user == null ? '?' : _initials(),
      style: TextStyle(
        fontFamily: kFontAppFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: cs.primary,
      ),
    );
  }
}
