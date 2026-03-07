import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import '../screens/recipe_detail_screen.dart';

/// Facebook-style notifications dropdown. Wrap the bell icon and show dropdown on tap.
class NotificationsDropdown extends StatefulWidget {
  final Widget child;
  final Color iconColor;

  const NotificationsDropdown({
    super.key,
    required this.child,
    this.iconColor = const Color(0xFFEF5026),
  });

  @override
  State<NotificationsDropdown> createState() => _NotificationsDropdownState();
}

class _NotificationsDropdownState extends State<NotificationsDropdown> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    final count = await NotificationService.instance.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _showOverlay() {
    if (_isOpen) return;
    _isOpen = true;
    _load();
    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _hideOverlay,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned(
              width: 320,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(-285, 48),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          Flexible(
                            child: _loading
                                ? const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(child: CircularProgressIndicator(color: wellGreen)),
                                  )
                                : _notifications.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade400),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No notifications yet',
                                              style: TextStyle(color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _notifications.length,
                                        itemBuilder: (context, index) {
                                          final n = _notifications[index];
                                          return _buildNotificationTile(n);
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: wellGreen,
            ),
          ),
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: TextStyle(fontSize: 13, color: wellGreen, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    return InkWell(
      onTap: () => _onTapNotification(n),
      child: Container(
        color: n.isRead ? null : wellGreen.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _colorForType(n.type).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconForType(n.type), color: _colorForType(n.type), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(n.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
    setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        NotificationService.instance.fetchNotifications(perPage: 15),
        NotificationService.instance.getUnreadCount(),
      ]);
      if (!mounted) return;
      _notifications = results[0] as List<AppNotification>;
      _unreadCount = results[1] as int;
    } catch (_) {
      _notifications = [];
    }
    _loading = false;
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    await NotificationService.instance.markAsRead(n.id);
    _load();
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.instance.markAllAsRead();
    _load();
  }

  void _onTapNotification(AppNotification n) {
    _markAsRead(n);
    final recipeId = n.data['recipe_id'] as int?;
    _hideOverlay();
    if (recipeId != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailScreen(recipeId: recipeId),
        ),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'recipe_liked':
      case 'post_liked':
        return Icons.favorite;
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
      case 'comment_received':
        return wellGreen;
      case 'content_reported':
        return nestOrange;
      default:
        return Colors.grey;
    }
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

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _showOverlay,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (_unreadCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: nestOrange,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    _unreadCount > 99 ? '99+' : '$_unreadCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
