import 'package:flutter/material.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/conversation_service.dart';
import 'package:wellnest/services/reverb_service.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/notifications_bell_button.dart';

/// Consistent header used on Discover, Feed, Saved, and Profile.
/// Logo + "Wellnest" on the left, notification bell + chat on the right.
class WellnestHeader extends StatelessWidget {
  static const double logoHeight = 40.0;
  static const double iconSize = 28.0;
  static const double fontSize = 22.0;

  const WellnestHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        /// LEFT SIDE (Logo + Title)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('lib/assets/images/logo1.png', height: logoHeight),
            const SizedBox(width: 10),
            Text(
              'Wellnest',
              style: georgiaProTextStyle(
                fontSize: fontSize,
                color: wellnestHeadingGreen(context),
              ).copyWith(letterSpacing: 0),
            ),
          ],
        ),

        /// RIGHT SIDE (Chat + Notifications)
        const WellnestHeaderActions(),
      ],
    );
  }
}

/// Chat + notification icons used on the right side of headers (Discover greeting row, etc.).
///
/// Use [wrapWithFlexible]: true (default) inside [Row]s that rely on [MainAxisAlignment.spaceBetween]
/// with a flexible left side. Use false when the actions sit after an [Expanded] left block so they
/// stay flush to the trailing edge.
class WellnestHeaderActions extends StatelessWidget {
  const WellnestHeaderActions({super.key, this.wrapWithFlexible = true});

  /// When true, wraps icons in [Flexible] for headers like [WellnestHeader]. When false, icons only
  /// take intrinsic width (e.g. Discover greeting row).
  final bool wrapWithFlexible;

  @override
  Widget build(BuildContext context) {
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChatBadgeButton(iconSize: WellnestHeader.iconSize),
        NotificationsBellButton(
          iconColor: AppColors.accentOrange,
          iconSize: WellnestHeader.iconSize,
        ),
      ],
    );

    if (!wrapWithFlexible) {
      return trailing;
    }

    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: _ChatBadgeButton(iconSize: WellnestHeader.iconSize),
          ),
          NotificationsBellButton(
            iconColor: AppColors.accentOrange,
            iconSize: WellnestHeader.iconSize,
          ),
        ],
      ),
    );
  }
}

class _ChatBadgeButton extends StatefulWidget {
  final double iconSize;

  const _ChatBadgeButton({required this.iconSize});

  @override
  State<_ChatBadgeButton> createState() => _ChatBadgeButtonState();
}

class _ChatBadgeButtonState extends State<_ChatBadgeButton>
    with WidgetsBindingObserver {
  final ConversationService _conversationService = ConversationService();
  late final VoidCallback _notificationUpdateHandler;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationUpdateHandler = _refreshUnreadMessages;
    _refreshUnreadMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureReverbSubscription());
  }

  Future<void> _ensureReverbSubscription() async {
    final userId = AuthService.instance.userId;
    if (userId == null || !mounted) return;
    try {
      await ReverbService.instance.subscribeToNotificationUpdates(
        userId,
        _notificationUpdateHandler,
      );
    } catch (_) {
      // Badge still updates on resume / after opening conversations.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUnreadMessages();
    }
  }

  @override
  void dispose() {
    final userId = AuthService.instance.userId;
    if (userId != null) {
      ReverbService.instance.unsubscribeFromNotificationUpdates(
        userId,
        _notificationUpdateHandler,
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshUnreadMessages() async {
    if (!AuthService.instance.isLoggedIn) {
      if (mounted) setState(() => _unreadMessages = 0);
      return;
    }

    try {
      final count = await _conversationService.getUnreadMessageCount();
      if (mounted) setState(() => _unreadMessages = count);
    } catch (_) {
      if (mounted) setState(() => _unreadMessages = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () async {
        await Navigator.of(context).pushNamed('/conversations');
        if (!mounted) return;
        _refreshUnreadMessages();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: AppColors.accentOrange,
            size: widget.iconSize,
          ),
          if (_unreadMessages > 0)
            Positioned(
              top: -3,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  _unreadMessages > 99 ? '99+' : '$_unreadMessages',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
