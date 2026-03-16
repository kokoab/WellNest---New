import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'recipe_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  List<AppNotification> _notifications = [];
  bool _loading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        NotificationService.instance.fetchNotifications(),
        NotificationService.instance.getUnreadCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _notifications = results[0] as List<AppNotification>;
        _unreadCount = results[1] as int;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _loading = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    // Optimistic: show as read immediately for instant feedback
    final idx = _notifications.indexWhere((x) => x.id == n.id);
    if (idx >= 0) {
      setState(() {
        _notifications[idx] = AppNotification(
          id: n.id,
          type: n.type,
          message: n.message,
          data: n.data,
          readAt: DateTime.now().toIso8601String(),
          createdAt: n.createdAt,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
    }
    await NotificationService.instance.markAsRead(n.id);
    if (mounted) _load();
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0) return;
    // Optimistic: clear unread styling immediately for instant feedback
    setState(() {
      _notifications = _notifications.map((n) {
        if (!n.isRead) {
          return AppNotification(
            id: n.id,
            type: n.type,
            message: n.message,
            data: n.data,
            readAt: DateTime.now().toIso8601String(),
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      _unreadCount = 0;
    });
    await NotificationService.instance.markAllAsRead();
    if (mounted) _load();
  }

  void _onTapNotification(AppNotification n) {
    _markAsRead(n);
    final recipeId = n.data['recipe_id'] as int?;
    final postId = n.data['post_id'] as int?;
    if (recipeId != null && mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => RecipeDetailScreen(recipeId: recipeId),
        ),
      );
    } else if (postId != null && mounted) {
      Navigator.pop(context);
      // Could navigate to post/feed with post focused
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'recipe_liked':
      case 'post_liked':
        return Icons.favorite;
      case 'recipe_rated':
        return Icons.star;
      case 'recipe_comment':
      case 'comment_received':
        return Icons.comment;
      case 'content_reported':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'recipe_liked':
      case 'post_liked':
        return Colors.pink;
      case 'recipe_rated':
        return const Color(0xFFFDB813);
      case 'recipe_comment':
      case 'comment_received':
        return wellGreen;
      case 'content_reported':
        return nestOrange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: wellGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 14),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: wellGreen))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: wellGreen,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return InkWell(
                        onTap: () => _onTapNotification(n),
                        child: Container(
                          color: n.isRead ? null : wellGreen.withOpacity(0.06),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _colorForType(n.type).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _iconForType(n.type),
                                  color: _colorForType(n.type),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.message,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(n.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
