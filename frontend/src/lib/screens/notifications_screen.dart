import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'recipe_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  static const Color wellGreen = Color(0xFF097333);
  static const Color wellGreenLight = Color(0xFFE8F5EE);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color nestOrangeLight = Color(0xFFFFF0EC);

  List<AppNotification> _notifications = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _perPage = 20;
  bool _markingRead = false;
  int _unreadCount = 0;
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _scrollController.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        NotificationService.instance.fetchNotificationsPaginated(
          page: 1,
          perPage: _perPage,
        ),
        NotificationService.instance.getUnreadCounts(),
      ]);
      if (!mounted) return;
      final notifRes = results[0] as NotificationListResponse;
      setState(() {
        _notifications = notifRes.notifications;
        _page = notifRes.currentPage;
        _hasMore = notifRes.currentPage < notifRes.lastPage;
        _unreadCount = (results[1] as NotificationCounts).allUnread;
        _loading = false;
      });
      _fadeController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications = [];
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final res = await NotificationService.instance
          .fetchNotificationsPaginated(page: nextPage, perPage: _perPage);
      if (!mounted) return;
      final existingIds = _notifications.map((n) => n.id).toSet();
      final incoming = res.notifications
          .where((n) => !existingIds.contains(n.id))
          .toList();
      setState(() {
        _notifications.addAll(incoming);
        _page = res.currentPage;
        _hasMore = res.currentPage < res.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    final idx = _notifications.indexWhere((x) => x.id == n.id);
    if (idx >= 0) {
      setState(() {
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
      });
    }
    await NotificationService.instance.markAsRead(n.id);
    if (mounted) _load();
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0 || _markingRead) return;
    setState(() => _markingRead = true);
    try {
      setState(() {
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
      });
      await NotificationService.instance.markAllAsRead();
      if (mounted) _load();
    } finally {
      if (mounted) setState(() => _markingRead = false);
    }
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

  ({Color bg, Color icon, Color dot}) _colorsForType(String type) {
    switch (type) {
      case 'recipe_liked':
      case 'post_liked':
        return (
          bg: const Color(0xFFFFEBF0),
          icon: const Color(0xFFE91E63),
          dot: const Color(0xFFE91E63),
        );
      case 'recipe_rated':
        return (
          bg: const Color(0xFFFFF8E1),
          icon: const Color(0xFFF9A825),
          dot: const Color(0xFFF9A825),
        );
      case 'recipe_comment':
      case 'comment_received':
        return (bg: wellGreenLight, icon: wellGreen, dot: wellGreen);
      case 'content_reported':
        return (bg: nestOrangeLight, icon: nestOrange, dot: nestOrange);
      default:
        return (
          bg: const Color(0xFFF0F0F0),
          icon: const Color(0xFF757575),
          dot: const Color(0xFF757575),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).toList();
    final read = _notifications.where((n) => n.isRead).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: wellGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 24),
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: nestOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _markingRead ? null : _markAllAsRead,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: _markingRead
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: wellGreen))
          : _notifications.isEmpty
          ? _buildEmptyState()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _load,
                color: wellGreen,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    if (unread.isNotEmpty) ...[
                      _buildSectionHeader('New', unread.length),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _NotificationCard(
                              notification: unread[i],
                              colors: _colorsForType(unread[i].type),
                              icon: _iconForType(unread[i].type),
                              isUnread: true,
                              onTap: () => _onTapNotification(unread[i]),
                              formatTime: _formatTime,
                              index: i,
                            ),
                            childCount: unread.length,
                          ),
                        ),
                      ),
                    ],
                    if (read.isNotEmpty) ...[
                      _buildSectionHeader('Earlier', null),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _NotificationCard(
                              notification: read[i],
                              colors: _colorsForType(read[i].type),
                              icon: _iconForType(read[i].type),
                              isUnread: false,
                              onTap: () => _onTapNotification(read[i]),
                              formatTime: _formatTime,
                              index: i,
                            ),
                            childCount: read.length,
                          ),
                        ),
                      ),
                    ],
                    if (_loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String label, int? count) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9E9E9E),
                letterSpacing: 0.8,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: wellGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: wellGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: wellGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 44,
              color: wellGreen.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D2D2D),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No notifications yet.\nWe\'ll let you know when something happens.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
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

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final ({Color bg, Color icon, Color dot}) colors;
  final IconData icon;
  final bool isUnread;
  final VoidCallback onTap;
  final String Function(String) formatTime;
  final int index;

  const _NotificationCard({
    required this.notification,
    required this.colors,
    required this.icon,
    required this.isUnread,
    required this.onTap,
    required this.formatTime,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isUnread ? Colors.white : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread
                    ? const Color(0xFF097333).withValues(alpha: 0.35)
                    : wellnestOutlineColor(context),
                width: isUnread ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: colors.icon, size: 22),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isUnread
                              ? const Color(0xFF1A1A1A)
                              : const Color(0xFF555555),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatTime(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Unread dot
                if (isUnread)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
