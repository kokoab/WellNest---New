import 'package:flutter/material.dart';
import 'package:wellnest/app_route_observer.dart';
import 'package:wellnest/models/post.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/screens/follow_list_screen.dart';
import 'package:wellnest/screens/post_detail_screen.dart';
import 'package:wellnest/screens/recipe_detail_screen.dart';
import 'package:wellnest/services/api_service.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/initials_avatar.dart';
import 'package:wellnest/widgets/profile_activity_helpers.dart';
import 'package:wellnest/widgets/profile_landscape_preview_card.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/recipe_service.dart';
import 'package:wellnest/services/user_service.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with RouteAware {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  PublicUserProfile? _profile;
  CurrentUser? _currentUser;
  List<Recipe> _recipes = [];
  List<Post> _posts = [];
  int _recipesPage = 1;
  int _recipesLastPage = 1;
  int _recipesTotal = 0;
  bool _recipesLoadingMore = false;
  int _postsPage = 1;
  int _postsLastPage = 1;
  int _postsTotal = 0;
  bool _postsLoadingMore = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isOwnProfile =>
      _currentUser != null && _currentUser!.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await UserService.instance.fetchPublicProfile(
        widget.userId,
      );
      final CurrentUser? currentUser = AuthService.instance.isLoggedIn
          ? await UserService.instance.fetchCurrentUser()
          : null;
      final isOwn = currentUser != null && currentUser.id == widget.userId;

      final recipesRes = await RecipeService.instance.fetchRecipes(
        userId: widget.userId,
        page: 1,
      );

      final PostListResponse postsRes = isOwn
          ? await ApiService().fetchPostsPaginated(
              userId: widget.userId,
              page: 1,
              perPage: 10,
            )
          : const PostListResponse(
              posts: [],
              currentPage: 1,
              lastPage: 1,
              total: 0,
              perPage: 10,
            );

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _currentUser = currentUser;
        _recipes = recipesRes.recipes;
        _recipesPage = recipesRes.currentPage;
        _recipesLastPage = recipesRes.lastPage;
        _recipesTotal = recipesRes.total;
        _posts = postsRes.posts;
        _postsPage = postsRes.currentPage;
        _postsLastPage = postsRes.lastPage;
        _postsTotal = postsRes.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreRecipes() async {
    if (_recipesLoadingMore || _recipesPage >= _recipesLastPage) return;
    setState(() => _recipesLoadingMore = true);
    try {
      final res = await RecipeService.instance.fetchRecipes(
        userId: widget.userId,
        page: _recipesPage + 1,
      );
      if (!mounted) return;
      final existing = _recipes.map((r) => r.id).toSet();
      final incoming = res.recipes
          .where((r) => !existing.contains(r.id))
          .toList();
      setState(() {
        _recipes.addAll(incoming);
        _recipesPage = res.currentPage;
        _recipesLastPage = res.lastPage;
        _recipesTotal = res.total;
        _recipesLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recipesLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load recipes: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_isOwnProfile) return;
    if (_postsLoadingMore || _postsPage >= _postsLastPage) return;
    setState(() => _postsLoadingMore = true);
    try {
      final res = await ApiService().fetchPostsPaginated(
        userId: widget.userId,
        page: _postsPage + 1,
        perPage: 10,
      );
      if (!mounted) return;
      final existing = _posts.map((p) => p.id).toSet();
      final incoming = res.posts
          .where((p) => !existing.contains(p.id))
          .toList();
      setState(() {
        _posts.addAll(incoming);
        _postsPage = res.currentPage;
        _postsLastPage = res.lastPage;
        _postsTotal = res.total;
        _postsLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _postsLoadingMore = false);
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _saving || _isOwnProfile) return;

    setState(() => _saving = true);

    try {
      final updated = profile.isFollowing == true
          ? await UserService.instance.unfollowUser(profile.id)
          : await UserService.instance.followUser(profile.id);
      if (!mounted) return;
      setState(() => _profile = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: wellGreen))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: nestOrange),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _buildContent(colorScheme),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final profile = _profile!;

    return RefreshIndicator(
      onRefresh: _load,
      color: wellGreen,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SizedBox(height: 12),
          Center(
            child: InitialsAvatar(
              name: profile.displayName,
              size: 88,
              imageUrl: profile.displayProfilePhotoUrl,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.displayName.isEmpty ? 'Unknown User' : profile.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: wellGreen,
            ),
          ),
          if (!profile.isAvailable) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: nestOrange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: nestOrange.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    profile.availabilityMessage ??
                        'User is not available right now.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: nestOrange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status: ${_statusLabel(profile.accountStatus)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('$_recipesTotal', 'Recipes'),
              if (_isOwnProfile) ...[
                const SizedBox(width: 24),
                _buildStat('$_postsTotal', 'Posts'),
              ],
              const SizedBox(width: 24),
              _buildStat(
                '${profile.followersCount}',
                'Followers',
                onTap: () => _openFollowList(FollowTab.followers),
              ),
              const SizedBox(width: 24),
              _buildStat(
                '${profile.followingCount}',
                'Following',
                onTap: () => _openFollowList(FollowTab.following),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (AuthService.instance.isLoggedIn &&
              !_isOwnProfile &&
              profile.isAvailable)
            FilledButton(
              onPressed: _saving ? null : _toggleFollow,
              style: FilledButton.styleFrom(
                backgroundColor: profile.isFollowing == true
                    ? colorScheme.surface
                    : wellGreen,
                foregroundColor: profile.isFollowing == true
                    ? colorScheme.onSurface
                    : Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(profile.isFollowing == true ? 'Unfollow' : 'Follow'),
            ),
          const SizedBox(height: 32),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recipes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: wellGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_recipes.isEmpty)
            Text(
              'No recipes yet.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            )
          else
            ..._recipes.map(
              (recipe) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm2),
                child: _buildRecipePreviewCard(recipe, profile.displayName),
              ),
            ),
          if (_recipesPage < _recipesLastPage) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _recipesLoadingMore ? null : _loadMoreRecipes,
              icon: _recipesLoadingMore
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(
                _recipesLoadingMore ? 'Loading…' : 'Load more recipes',
              ),
            ),
          ],
          if (_isOwnProfile) ...[
            const SizedBox(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Posts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: wellGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_posts.isEmpty)
              Text(
                'No posts yet.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              )
            else
              ..._posts.map(_buildPostCard),
            if (_postsPage < _postsLastPage) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _postsLoadingMore ? null : _loadMorePosts,
                icon: _postsLoadingMore
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(_postsLoadingMore ? 'Loading…' : 'Load more posts'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _openFollowList(FollowTab tab) {
    final profile = _profile;
    if (profile == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FollowListScreen(
          userId: widget.userId,
          displayName: profile.displayName,
          initialTab: tab,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'suspended':
        return 'Suspended';
      case 'deactivated':
        return 'Deactivated';
      default:
        return 'Active';
    }
  }

  Widget _buildStat(String value, String label, {VoidCallback? onTap}) {
    final column = Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: wellGreen,
          ),
        ),
        Text(label),
      ],
    );
    if (onTap == null) return column;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: column,
        ),
      ),
    );
  }

  Widget _buildRecipePreviewCard(Recipe recipe, String profileOwnerName) {
    final creator = recipe.userDisplayName.trim().isEmpty
        ? (profileOwnerName.trim().isEmpty ? 'Creator' : profileOwnerName)
        : recipe.userDisplayName;
    final when = formatProfilePostedAt(recipe.createdAt);
    return ProfileLandscapePreviewCard(
      title: recipe.title,
      creatorName: creator,
      postedLabel: when.isEmpty ? '—' : when,
      imageUrl: recipePreviewImageUrl(recipe),
      placeholderIcon: Icons.restaurant_rounded,
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: wellnestOutlineColor(context), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => PostDetailScreen(post: post),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.content, maxLines: 4, overflow: TextOverflow.ellipsis),
              if (post.displayImageUrl != null &&
                  post.displayImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.displayImageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
