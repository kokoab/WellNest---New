import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wellnest/app_route_observer.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/reverb_service.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/utils/media_url.dart';
import 'package:wellnest/widgets/initials_avatar.dart';
import '../models/notification.dart';
import '../services/notification_service.dart';
import 'conversation_chat_screen.dart';
import 'recipe_detail_screen.dart';

String _notificationActorDisplayName(AppNotification n) {
  final d = n.data;
  for (final key in <String>[
    'sender_name',
    'liker_name',
    'commenter_name',
    'rater_name',
    'reporter_name',
  ]) {
    final v = d[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

bool _notificationIsWellnestAi(AppNotification n) {
  if (n.type != 'new_message') return false;
  final v = n.data['is_wellnest_assistant'];
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    return v == '1' || v.toLowerCase() == 'true';
  }
  return false;
}

/// True when this row should show the bundled assistant logo (API flag or legacy payload by name).
bool _notificationShowsAssistantLogo(AppNotification n) {
  if (_notificationIsWellnestAi(n)) return true;
  if (n.type != 'new_message') return false;
  final raw = _notificationActorDisplayName(n).toLowerCase();
  return raw.contains('wellnest') && raw.contains('assistant');
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with RouteAware, SingleTickerProviderStateMixin {
  static const Color wellGreen = Color(0xFF097333);
  static const Color wellGreenLight = Color(0xFFE8F5EE);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color nestOrangeLight = Color(0xFFFFF0EC);
  /// Keeps notification cards readable on wide web layouts.
  static const double _contentMaxWidth = 560;

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
  late final VoidCallback _reverbRefreshHandler;

  @override
  void initState() {
    super.initState();
    _reverbRefreshHandler = () {
      if (mounted) unawaited(_load());
    };
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
    final userId = AuthService.instance.userId;
    if (userId != null) {
      unawaited(
        ReverbService.instance.subscribeToNotificationUpdates(
          userId,
          _reverbRefreshHandler,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
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
    final userId = AuthService.instance.userId;
    if (userId != null) {
      unawaited(
        ReverbService.instance.unsubscribeFromNotificationUpdates(
          userId,
          _reverbRefreshHandler,
        ),
      );
    }
    appRouteObserver.unsubscribe(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _load();
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

  int? _dataInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  String _senderNameFromNotification(AppNotification n) {
    final name = _notificationActorDisplayName(n);
    if (name.isNotEmpty) return name;
    return 'Chat';
  }

  void _onTapNotification(AppNotification n) {
    _markAsRead(n);
    final recipeId = _dataInt(n.data['recipe_id']);
    final postId = _dataInt(n.data['post_id']);
    final conversationId = _dataInt(n.data['conversation_id']);
    if (!mounted) return;

    if (conversationId != null && n.type == 'new_message') {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationChatScreen(
            conversationId: conversationId,
            otherUserName: _senderNameFromNotification(n),
            otherUserProfilePhotoUrl:
                n.data['actor_profile_photo_url'] as String?,
            isAssistant: _notificationIsWellnestAi(n),
          ),
        ),
      );
      return;
    }

    if (recipeId != null) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => RecipeDetailScreen(recipeId: recipeId),
        ),
      );
    } else if (postId != null) {
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
      case 'new_message':
        return Icons.chat_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  ({Color bg, Color icon, Color dot}) _colorsForType(String type, bool isDark) {
    switch (type) {
      case 'recipe_liked':
      case 'post_liked':
        return (
          bg: isDark ? const Color(0xFF3A2630) : const Color(0xFFFFEBF0),
          icon: const Color(0xFFE91E63),
          dot: const Color(0xFFE91E63),
        );
      case 'recipe_rated':
        return (
          bg: isDark ? const Color(0xFF3A3626) : const Color(0xFFFFF8E1),
          icon: const Color(0xFFF9A825),
          dot: const Color(0xFFF9A825),
        );
      case 'recipe_comment':
      case 'comment_received':
        return (
          bg: isDark ? wellGreen.withValues(alpha: 0.22) : wellGreenLight,
          icon: wellGreen,
          dot: wellGreen,
        );
      case 'content_reported':
        return (
          bg: isDark ? nestOrange.withValues(alpha: 0.22) : nestOrangeLight,
          icon: nestOrange,
          dot: nestOrange,
        );
      default:
        return (
          bg: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
          icon: const Color(0xFF757575),
          dot: const Color(0xFF757575),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).toList();
    final read = _notifications.where((n) => n.isRead).toList();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: cs.onSurface, size: 24),
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            color: cs.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: _markingRead ? null : _markAllAsRead,
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                child: _markingRead
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: cs.primary,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Mark all read',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: _loading
              ? Center(child: CircularProgressIndicator(color: cs.primary))
              : _notifications.isEmpty
              ? _buildEmptyState(context)
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: cs.primary,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                    if (unread.isNotEmpty) ...[
                      _buildSectionHeader(context, 'New', unread.length),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _NotificationCard(
                              notification: unread[i],
                              colors: _colorsForType(unread[i].type, isDark),
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
                      _buildSectionHeader(context, 'Earlier', null),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _NotificationCard(
                              notification: read[i],
                              colors: _colorsForType(read[i].type, isDark),
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
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String label, int? count) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No notifications yet.\nWe\'ll let you know when something happens.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
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
              color: isUnread ? cs.surface : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread
                    ? cs.primary.withValues(alpha: 0.45)
                    : wellnestOutlineColor(context),
                width: isUnread ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NotificationLeadAvatar(
                  notification: notification,
                  colors: colors,
                  fallbackIcon: icon,
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
                              ? cs.onSurface
                              : cs.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatTime(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
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

class _NotificationLeadAvatar extends StatelessWidget {
  const _NotificationLeadAvatar({
    required this.notification,
    required this.colors,
    required this.fallbackIcon,
  });

  final AppNotification notification;
  final ({Color bg, Color icon, Color dot}) colors;
  final IconData fallbackIcon;

  Widget _fallbackIconBox() {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(fallbackIcon, color: colors.icon, size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_notificationShowsAssistantLogo(notification)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Image.asset(
            kWellnestAssistantLogoAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: const InitialsAvatar(name: 'WellNest AI', size: 46),
            ),
          ),
        ),
      );
    }

    final raw = notification.data['actor_profile_photo_url'] as String?;
    final photoUrl = resolveStorageDisplayUrl(raw);
    final name = _notificationActorDisplayName(notification);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          photoUrl,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => name.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: InitialsAvatar(name: name, size: 46),
                )
              : _fallbackIconBox(),
        ),
      );
    }

    if (name.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InitialsAvatar(name: name, size: 46),
      );
    }

    return _fallbackIconBox();
  }
}
