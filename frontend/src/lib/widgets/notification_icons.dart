import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/services/notification_service.dart';
import 'package:my_app/theme/app_theme.dart';

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

class _NotificationIconsState extends State<NotificationIcons> {
  int _messageCount = 0;
  int _activityCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _fetchCounts();
    });
  }

  Future<void> _fetchCounts() async {
    try {
      final notificationService = NotificationService.instance;
      
      // Get all notifications and categorize them
      final notifications = await notificationService.fetchNotifications();
      
      int messages = 0;
      int activity = 0;
      
      for (final notification in notifications) {
        if (notification.isRead) continue;
        if (_isMessageNotification(notification.type, notification.data)) {
          messages++;
        } else if (_isActivityNotification(notification.type, notification.data)) {
          activity++;
        }
      }
      
      if (mounted) {
        setState(() {
          _messageCount = messages;
          _activityCount = activity;
        });
      }
    } catch (_) {
      // Keep previous counts if fetch fails.
    }
  }

  bool _isMessageNotification(String type, Map<String, dynamic> data) {
    final normalized = type.toLowerCase();
    if (normalized.contains('message') ||
        normalized.contains('chat') ||
        normalized.contains('conversation')) {
      return true;
    }
    return data.containsKey('conversation_id') ||
        data.containsKey('message_id') ||
        data['channel']?.toString().toLowerCase() == 'message';
  }

  bool _isActivityNotification(String type, Map<String, dynamic> data) {
    final normalized = type.toLowerCase();
    if (normalized.contains('like') ||
        normalized.contains('comment') ||
        normalized.contains('vote') ||
        normalized.contains('follow') ||
        normalized.contains('mention')) {
      return true;
    }
    return data.containsKey('post_id') ||
        data.containsKey('comment_id') ||
        data.containsKey('recipe_id') ||
        data['channel']?.toString().toLowerCase() == 'activity';
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
              Icon(
                count > 0 ? filledIcon : icon,
                color: color,
                size: 24,
              ),
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