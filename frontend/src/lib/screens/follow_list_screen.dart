import 'package:flutter/material.dart';
import 'package:wellnest/screens/user_profile_screen.dart';
import 'package:wellnest/services/user_service.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/initials_avatar.dart';

/// Which tab to show first on [FollowListScreen].
enum FollowTab {
  followers,
  following,
}

/// Paginated followers / following for a user (two tabs).
class FollowListScreen extends StatefulWidget {
  final int userId;
  final String? displayName;
  final FollowTab initialTab;

  const FollowListScreen({
    super.key,
    required this.userId,
    this.displayName,
    required this.initialTab,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == FollowTab.followers ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.displayName ?? '').trim().isNotEmpty
        ? widget.displayName!.trim()
        : 'Followers';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowListTab(userId: widget.userId, followers: true),
          _FollowListTab(userId: widget.userId, followers: false),
        ],
      ),
    );
  }
}

class _FollowListTab extends StatefulWidget {
  final int userId;
  final bool followers;

  const _FollowListTab({required this.userId, required this.followers});

  @override
  State<_FollowListTab> createState() => _FollowListTabState();
}

class _FollowListTabState extends State<_FollowListTab> {
  final ScrollController _scroll = ScrollController();
  final List<PublicUserProfile> _items = [];

  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  /// True while pull-to-refresh is loading (avoid bottom spinner on multi-page lists).
  bool _refreshing = false;
  bool _hadError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchPage(reset: true));
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading) return;
    if (_page >= _lastPage) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _fetchPage(reset: false);
    }
  }

  Future<void> _fetchPage({required bool reset}) async {
    if (_loading) return;
    final nextPage = reset ? 1 : _page + 1;
    if (!reset && _page >= _lastPage) return;

    setState(() {
      _loading = true;
      _refreshing = reset && _items.isNotEmpty;
      if (reset) {
        _hadError = false;
        _errorMessage = null;
      }
    });

    try {
      final res = widget.followers
          ? await UserService.instance.fetchFollowers(
              widget.userId,
              page: nextPage,
            )
          : await UserService.instance.fetchFollowingList(
              widget.userId,
              page: nextPage,
            );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(res.users);
        } else {
          final ids = _items.map((e) => e.id).toSet();
          for (final u in res.users) {
            if (!ids.contains(u.id)) {
              _items.add(u);
            }
          }
        }
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _loading = false;
        _refreshing = false;
        _hadError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        if (reset) {
          _hadError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emptyLabel = widget.followers
        ? 'No followers yet.'
        : 'Not following anyone yet.';

    if (_hadError && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _fetchPage(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return RefreshIndicator(
      color: kPrimaryGreen,
      onRefresh: () => _fetchPage(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length +
            (_loading && _page < _lastPage && !_refreshing ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final user = _items[index];
          return ListTile(
            leading: InitialsAvatar(
              name: user.displayName,
              size: 44,
              imageUrl: user.displayProfilePhotoUrl,
            ),
            title: Text(
              user.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: user.isAvailable
                ? null
                : Text(
                    user.availabilityMessage ?? 'Unavailable',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
            onTap: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => UserProfileScreen(userId: user.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
