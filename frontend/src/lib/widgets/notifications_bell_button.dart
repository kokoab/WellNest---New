import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/notification_service.dart';
import 'package:wellnest/services/reverb_service.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Bell icon with unread badge; opens [NotificationsScreen] via `/notifications`.
class NotificationsBellButton extends StatefulWidget {
  const NotificationsBellButton({
    super.key,
    this.iconSize = 28,
    this.iconColor = AppColors.accentOrange,
    this.icon = Icons.notifications,
    this.borderedToolbar = false,
    this.tooltip = 'Notifications',
  });

  final double iconSize;
  final Color iconColor;
  final IconData icon;

  /// When true, matches admin top bar bordered controls (40×40, smaller icon).
  final bool borderedToolbar;
  final String tooltip;

  @override
  State<NotificationsBellButton> createState() =>
      _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<NotificationsBellButton>
    with WidgetsBindingObserver {
  static const Color _nestOrange = Color(0xFFEF5026);
  static const double _toolbarSize = 40;

  int _unreadCount = 0;
  late final VoidCallback _badgeRefreshHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _badgeRefreshHandler = _fetchUnreadCount;
    _fetchUnreadCount();
    _subscribeReverb();
  }

  Future<void> _subscribeReverb() async {
    final userId = AuthService.instance.userId;
    if (userId == null) return;
    try {
      await ReverbService.instance.subscribeToNotificationUpdates(
        userId,
        _badgeRefreshHandler,
      );
    } catch (_) {
      // Badge still updates on resume and after opening notifications screen.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUnreadCount();
    }
  }

  @override
  void dispose() {
    final userId = AuthService.instance.userId;
    if (userId != null) {
      ReverbService.instance.unsubscribeFromNotificationUpdates(
        userId,
        _badgeRefreshHandler,
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final counts = await NotificationService.instance.getUnreadCounts();
      if (mounted) {
        setState(() => _unreadCount = counts.allUnread);
      }
    } catch (_) {
      // Keep prior count on failure.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).pushNamed('/notifications');
    if (!mounted) return;
    unawaited(_fetchUnreadCount());
  }

  @override
  Widget build(BuildContext context) {
    final iconSz =
        widget.borderedToolbar ? 20.0 : widget.iconSize;

    final bell = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.icon, color: widget.iconColor, size: iconSz),
        if (_unreadCount > 0)
          Positioned(
            top: widget.borderedToolbar ? 2 : -3,
            right: widget.borderedToolbar ? 2 : -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: _nestOrange,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadCount > 99 ? '99+' : '$_unreadCount',
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
    );

    if (widget.borderedToolbar) {
      return Tooltip(
        message: widget.tooltip,
        child: SizedBox.square(
          dimension: _toolbarSize,
          child: IconButton(
            onPressed: _openNotifications,
            tooltip: widget.tooltip,
            style: IconButton.styleFrom(
              minimumSize: const Size(_toolbarSize, _toolbarSize),
              maximumSize: const Size(_toolbarSize, _toolbarSize),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: BorderSide(
                color: widget.iconColor.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            icon: bell,
          ),
        ),
      );
    }

    return IconButton(
      onPressed: _openNotifications,
      tooltip: widget.tooltip,
      icon: bell,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
