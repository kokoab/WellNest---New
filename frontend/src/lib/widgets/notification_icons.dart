import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/notification_service.dart';
import 'package:wellnest/services/reverb_service.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Split notification icons for the app bar.
/// - Message icon (chat bubble) with red badge for new messages
/// - Activity/Bell icon with red badge for likes/comments
class NotificationIcons extends StatefulWidget {
  final Color iconColor;
  final VoidCallback? onMessageTap;
  final VoidCallback? onActivityTap;

  const NotificationIcons({
    super.key,
    this.iconColor = kAccentOrange,
    this.onMessageTap,
    this.onActivityTap,
  });

  @override
  State<NotificationIcons> createState() => _NotificationIconsState();
}

class _NotificationIconsState extends State<NotificationIcons>
    with WidgetsBindingObserver {
  int _messageCount = 0;
  int _activityCount = 0;
  late final VoidCallback _notificationUpdateHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationUpdateHandler = _fetchCounts;
    _fetchCounts();
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
      // Counts refresh on resume / when opening notifications.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchCounts();
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

  Future<void> _fetchCounts() async {
    try {
      final counts = await NotificationService.instance.getUnreadCounts();
      if (mounted) {
        setState(() {
          _messageCount = counts.messageUnread;
          _activityCount = counts.activityUnread;
        });
      }
    } catch (_) {
      // Keep previous counts if fetch fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Message Icon
        _NotificationIconWithBadge(
          icon: Icons.message_outlined,
          filledIcon: Icons.message,
          count: _messageCount,
          color: widget.iconColor,
          onTap: widget.onMessageTap,
          tooltip: 'Messages',
        ),
        const SizedBox(width: 8),
        // Activity/Bell Icon
        _NotificationIconWithBadge(
          icon: Icons.notifications_outlined,
          filledIcon: Icons.notifications,
          count: _activityCount,
          color: widget.iconColor,
          onTap: widget.onActivityTap,
          tooltip: 'Activity',
        ),
      ],
    );
  }
}

class _NotificationIconWithBadge extends StatelessWidget {
  final IconData icon;
  final IconData filledIcon;
  final int count;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  const _NotificationIconWithBadge({
    required this.icon,
    required this.filledIcon,
    required this.count,
    required this.color,
    this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(count > 0 ? filledIcon : icon, color: color, size: 24),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
