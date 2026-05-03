import 'package:flutter/material.dart';
import 'dart:async';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/conversation_service.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/widgets/georgia_pro_display_squish.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';

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
            GeorgiaProDisplaySquish(
              child: Text(
                'Wellnest',
                style: georgiaProTextStyle(
                  fontSize: fontSize,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),

        /// RIGHT SIDE (Chat + Notifications)
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: _ChatBadgeButton(iconSize: iconSize)),
              NotificationsDropdown(
                iconColor: AppColors.accentOrange,
                child: Icon(
                  Icons.notifications,
                  color: AppColors.accentOrange,
                  size: iconSize,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBadgeButton extends StatefulWidget {
  final double iconSize;

  const _ChatBadgeButton({required this.iconSize});

  @override
  State<_ChatBadgeButton> createState() => _ChatBadgeButtonState();
}

class _ChatBadgeButtonState extends State<_ChatBadgeButton> {
  final ConversationService _conversationService = ConversationService();
  Timer? _pollTimer;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnreadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshUnreadMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
