import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';
import '../models/notification.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/reverb_service.dart';
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

class _NotificationsDropdownState extends State<NotificationsDropdown>
    with WidgetsBindingObserver {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _isOpen = false;
  late final VoidCallback _notificationUpdateHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationUpdateHandler = _fetchUnreadCount;
    _fetchUnreadCount();
    final userId = AuthService.instance.userId;
    if (userId != null) {
      ReverbService.instance.subscribeToNotificationUpdates(
        userId,
        _notificationUpdateHandler,
      );
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
        _notificationUpdateHandler,
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchUnreadCount() async {
    final counts = await NotificationService.instance.getUnreadCounts();
    if (mounted) setState(() => _unreadCount = counts.activityUnread);
  }

  void _showOverlay() {
    if (_isOpen || !mounted) return;
    _isOpen = true;
    _load();
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return GestureDetector(
          onTap: _hideOverlay,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned(
                width: 340,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: const Offset(-300, 52),
                  child: Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 480),
                        decoration: wellnestCardDecoration(overlayContext),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Builder(
                            builder: (ctx) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeader(ctx),
                                  Flexible(
                                    child: _loading
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 40,
                                            ),
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: wellGreen,
                                                strokeWidth: 2.5,
                                              ),
                                            ),
                                          )
                                        : _notifications.isEmpty
                                        ? _buildEmptyState()
                                        : ListView.separated(
                                            shrinkWrap: true,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 6,
                                            ),
                                            itemCount: _notifications.length,
                                            separatorBuilder: (_, __) =>
                                                Divider(
                                                  height: 1,
                                                  indent: 66,
                                                  endIndent: 14,
                                                  color: Colors.grey
                                                      .withOpacity(0.1),
                                                ),
                                            itemBuilder: (c, index) {
                                              final n = _notifications[index];
                                              return _buildNotificationTile(
                                                c,
                                                n,
                                              );
                                            },
                                          ),
                                  ),
                                  _buildFooter(ctx),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (context.mounted) {
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _isOpen = false;
      _overlayEntry = null;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 13),
      decoration: const BoxDecoration(color: wellGreen),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_rounded,
            color: Colors.white,
            size: 19,
          ),
          const SizedBox(width: 8),
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: nestOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_unreadCount new',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: wellGreen.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 28,
              color: wellGreen.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No notifications yet',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return GestureDetector(
      onTap: _hideOverlay,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.12))),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'See all notifications',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: wellGreen,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 14, color: wellGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, AppNotification n) {
    final isUnread = !n.isRead;
    final colors = _colorsForType(n.type);
    return InkWell(
      onTap: () => _onTapNotification(n),
      child: Container(
        color: isUnread ? wellGreen.withOpacity(0.035) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForType(n.type), color: colors.fg, size: 19),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isUnread
                          ? const Color(0xFF111111)
                          : const Color(0xFF555555),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(n.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isUnread
                          ? wellGreen.withOpacity(0.7)
                          : Colors.grey.shade400,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Unread dot
            if (isUnread)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: colors.fg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isOpen = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        NotificationService.instance.fetchNotifications(
          perPage: 15,
          category: NotificationCategory.activity,
        ),
        NotificationService.instance.getUnreadCounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _notifications = results[0] as List<AppNotification>;
        _unreadCount = (results[1] as NotificationCounts).activityUnread;
        _loading = false;
      });
      _overlayEntry?.markNeedsBuild();
    } catch (_) {
      if (mounted) {
        setState(() {
          _notifications = [];
          _loading = false;
        });
      }
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _updateUI() {
    if (mounted) setState(() {});
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    // Optimistic: show as read immediately for instant feedback
    final idx = _notifications.indexWhere((x) => x.id == n.id);
    if (idx >= 0) {
      _notifications[idx] = AppNotification(
        id: n.id,
        type: n.type,
        category: n.category,
        message: n.message,
        data: n.data,
        readAt: DateTime.now().toIso8601String(),
        createdAt: n.createdAt,
      );
      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      _updateUI();
    }
    unawaited(NotificationService.instance.markAsRead(n.id));
    unawaited(_load(showLoading: false)); // Sync in background
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0) return;
    // Optimistic: clear unread styling immediately for instant feedback
    _notifications = _notifications.map((n) {
      if (!n.isRead) {
        return AppNotification(
          id: n.id,
          type: n.type,
          category: n.category,
          message: n.message,
          data: n.data,
          readAt: DateTime.now().toIso8601String(),
          createdAt: n.createdAt,
        );
      }
      return n;
    }).toList();
    _unreadCount = 0;
    _updateUI();
    unawaited(NotificationService.instance.markAllAsRead());
    unawaited(_load(showLoading: false)); // Sync in background
  }

  void _onTapNotification(AppNotification n) {
    unawaited(_markAsRead(n));
    final recipeId = n.data['recipe_id'] as int?;
    _hideOverlay();
    if (recipeId != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => RecipeDetailScreen(recipeId: recipeId),
        ),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'recipe_liked':
      case 'post_liked':
        return Icons.favorite_rounded;
      case 'recipe_rated':
        return Icons.star_rounded;
      case 'recipe_comment':
      case 'comment_received':
        return Icons.chat_bubble_rounded;
      case 'content_reported':
        return Icons.flag_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  ({Color bg, Color fg}) _colorsForType(String type) {
    switch (type) {
      case 'recipe_liked':
      case 'post_liked':
        return (bg: const Color(0xFFFFEBF0), fg: const Color(0xFFE91E63));
      case 'recipe_rated':
        return (bg: const Color(0xFFFFF8E1), fg: const Color(0xFFF9A825));
      case 'recipe_comment':
      case 'comment_received':
        return (bg: const Color(0xFFE8F5EE), fg: wellGreen);
      case 'content_reported':
        return (bg: const Color(0xFFFFF0EC), fg: nestOrange);
      default:
        return (bg: const Color(0xFFF0F0F0), fg: const Color(0xFF757575));
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
  void deactivate() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isOpen = false;
    }
    super.deactivate();
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
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: nestOrange,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
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
          ),
        ),
      ),
    );
  }
}
