import 'package:flutter/material.dart';
import 'package:wellnest/app_route_observer.dart';
import 'package:wellnest/models/post.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/screens/post_detail_screen.dart';
import 'package:wellnest/screens/recipe_detail_screen.dart';
import 'package:wellnest/services/api_service.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/content_update_notifier.dart';
import 'package:wellnest/services/recipe_service.dart';
import 'package:wellnest/services/user_service.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/profile_activity_helpers.dart';
import 'package:wellnest/widgets/profile_landscape_preview_card.dart';

/// Full lists for profile activity — opened from Profile **See all** (same 3 tabs).
class ProfileActivityScreen extends StatefulWidget {
  /// 0 = My Recipes, 1 = My Posts, 2 = Liked (heart on recipes & posts).
  final int initialTabIndex;

  const ProfileActivityScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ProfileActivityScreen> createState() => _ProfileActivityScreenState();
}

class _ProfileActivityScreenState extends State<ProfileActivityScreen>
    with RouteAware {
  static const Color kLikedHeartRed = Color(0xFFE53935);

  int _tabIndex = 0;

  CurrentUser? _user;
  List<Recipe> _myRecipes = [];
  int _myRecipesPage = 1;
  int _myRecipesLastPage = 1;
  bool _myRecipesLoadingMore = false;

  List<Post> _myPosts = [];
  int _myPostsPage = 1;
  int _myPostsLastPage = 1;
  bool _myPostsLoadingMore = false;

  List<Recipe> _likedHeartRecipes = [];
  int _likedHeartRecipesPage = 1;
  int _likedHeartRecipesLastPage = 1;
  List<Post> _likedHeartPosts = [];
  int _likedHeartPostsPage = 1;
  int _likedHeartPostsLastPage = 1;
  bool _likedHeartLoadingMore = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 2);
    ContentUpdateNotifier.instance.addListener(_onContentUpdate);
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
    ContentUpdateNotifier.instance.removeListener(_onContentUpdate);
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  void _onContentUpdate() {
    final update = ContentUpdateNotifier.instance.lastUpdate;
    if (!mounted || update == null) return;
    if (update.action != ContentUpdateAction.likeChanged) return;

    if (update.isActive) {
      _load();
      return;
    }

    setState(() {
      switch (update.kind) {
        case ContentUpdateKind.recipe:
          _likedHeartRecipes.removeWhere((recipe) => recipe.id == update.id);
          break;
        case ContentUpdateKind.post:
          _likedHeartPosts.removeWhere((post) => post.id == update.id);
          break;
      }
    });
  }

  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = AuthService.instance.isLoggedIn
          ? await UserService.instance.fetchCurrentUser()
          : null;
      if (!mounted) return;

      RecipeListResponse? recipesResponse;
      PostListResponse? postsResponse;
      RecipeListResponse? likedRecipesResponse;
      PostListResponse? likedPostsResponse;

      if (user != null) {
        final futures = <Future<dynamic>>[
          RecipeService.instance.fetchRecipes(userId: user.id, page: 1),
          ApiService().fetchPostsPaginated(
            userId: user.id,
            page: 1,
            perPage: 10,
          ),
        ];
        if (AuthService.instance.isLoggedIn) {
          futures.add(RecipeService.instance.fetchRecipes(liked: true, page: 1));
          futures.add(
            ApiService().fetchPostsPaginated(liked: true, page: 1, perPage: 10),
          );
        }
        final results = await Future.wait(futures);
        recipesResponse = results[0] as RecipeListResponse;
        postsResponse = results[1] as PostListResponse;
        if (AuthService.instance.isLoggedIn && results.length > 3) {
          likedRecipesResponse = results[2] as RecipeListResponse;
          likedPostsResponse = results[3] as PostListResponse;
        }
      }

      if (!mounted) return;
      setState(() {
        _user = user;
        _myRecipes = recipesResponse?.recipes ?? [];
        _myRecipesPage = recipesResponse?.currentPage ?? 1;
        _myRecipesLastPage = recipesResponse?.lastPage ?? 1;
        _myPosts = postsResponse?.posts ?? [];
        _myPostsPage = postsResponse?.currentPage ?? 1;
        _myPostsLastPage = postsResponse?.lastPage ?? 1;
        _likedHeartRecipes = likedRecipesResponse?.recipes ?? [];
        _likedHeartRecipesPage = likedRecipesResponse?.currentPage ?? 1;
        _likedHeartRecipesLastPage = likedRecipesResponse?.lastPage ?? 1;
        _likedHeartPosts = likedPostsResponse?.posts ?? [];
        _likedHeartPostsPage = likedPostsResponse?.currentPage ?? 1;
        _likedHeartPostsLastPage = likedPostsResponse?.lastPage ?? 1;
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

  Future<void> _loadMoreMyRecipes() async {
    if (_myRecipesLoadingMore || _myRecipesPage >= _myRecipesLastPage) return;
    final user = _user;
    if (user == null) return;
    setState(() => _myRecipesLoadingMore = true);
    try {
      final response = await RecipeService.instance.fetchRecipes(
        userId: user.id,
        page: _myRecipesPage + 1,
      );
      if (!mounted) return;
      final existingIds = _myRecipes.map((r) => r.id).toSet();
      final incoming = response.recipes
          .where((r) => !existingIds.contains(r.id))
          .toList();
      setState(() {
        _myRecipes.addAll(incoming);
        _myRecipesPage = response.currentPage;
        _myRecipesLastPage = response.lastPage;
        _myRecipesLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _myRecipesLoadingMore = false);
    }
  }

  Future<void> _loadMoreMyPosts() async {
    if (_myPostsLoadingMore || _myPostsPage >= _myPostsLastPage) return;
    final user = _user;
    if (user == null) return;
    setState(() => _myPostsLoadingMore = true);
    try {
      final response = await ApiService().fetchPostsPaginated(
        userId: user.id,
        page: _myPostsPage + 1,
        perPage: 10,
      );
      if (!mounted) return;
      final existingIds = _myPosts.map((p) => p.id).toSet();
      final incoming =
          response.posts.where((p) => !existingIds.contains(p.id)).toList();
      setState(() {
        _myPosts.addAll(incoming);
        _myPostsPage = response.currentPage;
        _myPostsLastPage = response.lastPage;
        _myPostsLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _myPostsLoadingMore = false);
    }
  }

  Future<void> _loadMoreLikedHeart() async {
    if (_likedHeartLoadingMore) return;
    final needRecipes =
        _likedHeartRecipesPage < _likedHeartRecipesLastPage;
    final needPosts = _likedHeartPostsPage < _likedHeartPostsLastPage;
    if (!needRecipes && !needPosts) return;
    if (!AuthService.instance.isLoggedIn) return;

    setState(() => _likedHeartLoadingMore = true);
    try {
      final futures = <Future<dynamic>>[];
      if (needRecipes) {
        futures.add(
          RecipeService.instance.fetchRecipes(
            liked: true,
            page: _likedHeartRecipesPage + 1,
          ),
        );
      }
      if (needPosts) {
        futures.add(
          ApiService().fetchPostsPaginated(
            liked: true,
            page: _likedHeartPostsPage + 1,
            perPage: 10,
          ),
        );
      }
      final out = await Future.wait(futures);
      var i = 0;
      if (needRecipes) {
        final response = out[i++] as RecipeListResponse;
        final existing = _likedHeartRecipes.map((r) => r.id).toSet();
        final incoming = response.recipes
            .where((r) => !existing.contains(r.id))
            .toList();
        _likedHeartRecipes.addAll(incoming);
        _likedHeartRecipesPage = response.currentPage;
        _likedHeartRecipesLastPage = response.lastPage;
      }
      if (needPosts) {
        final response = out[i] as PostListResponse;
        final existing = _likedHeartPosts.map((p) => p.id).toSet();
        final incoming = response.posts
            .where((p) => !existing.contains(p.id))
            .toList();
        _likedHeartPosts.addAll(incoming);
        _likedHeartPostsPage = response.currentPage;
        _likedHeartPostsLastPage = response.lastPage;
      }
      if (mounted) setState(() => _likedHeartLoadingMore = false);
    } catch (_) {
      if (mounted) setState(() => _likedHeartLoadingMore = false);
    }
  }

  Color _tabSurface(int tab) {
    switch (tab) {
      case 0:
        return kAccentOrange.withValues(alpha: 0.12);
      case 1:
        return kPrimaryGreen.withValues(alpha: 0.12);
      default:
        return kLikedHeartRed.withValues(alpha: 0.10);
    }
  }

  Color _tabIconColor(int tab, bool selected) {
    if (!selected) return kCaptionGray;
    switch (tab) {
      case 0:
        return kAccentOrange;
      case 1:
        return kPrimaryGreen;
      default:
        return kLikedHeartRed;
    }
  }

  Widget _tabButton(int index, IconData icon, String tooltip) {
    final selected = _tabIndex == index;
    final outline = wellnestOutlineColor(context);
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _tabIndex = index),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected ? _tabSurface(index) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: selected ? outline : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: _tabIconColor(index, selected),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recipeCard(Recipe recipe) {
    final creator = recipe.userDisplayName.trim().isEmpty
        ? (_user?.displayName ?? 'Creator')
        : recipe.userDisplayName;
    final when = formatProfilePostedAt(recipe.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm2),
      child: ProfileLandscapePreviewCard(
        title: recipe.title,
        creatorName: creator,
        postedLabel: when.isEmpty ? '—' : when,
        imageUrl: recipePreviewImageUrl(recipe),
        placeholderIcon: Icons.restaurant_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
          ),
        ),
      ),
    );
  }

  Widget _postCard(Post post) {
    final when = formatProfilePostedAt(post.createdAt);
    final img = post.displayImageUrl ??
        (post.galleryImages.isNotEmpty
            ? post.galleryImages.first.displayUrl
            : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm2),
      child: ProfileLandscapePreviewCard(
        title: postPreviewTitle(post),
        creatorName:
            post.userName.trim().isEmpty ? 'Member' : post.userName.trim(),
        postedLabel: when.isEmpty ? '—' : when,
        imageUrl: img,
        placeholderIcon: Icons.article_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => PostDetailScreen(post: post),
          ),
        ),
      ),
    );
  }

  Widget _likedCard(LikedActivityRow row) {
    if (row.recipe != null) return _recipeCard(row.recipe!);
    return _postCard(row.post!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: kPrimaryGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your activity',
          style: georgiaProDisplayStyle(fontSize: 18, color: kPrimaryGreen),
        ),
      ),
      body: RefreshIndicator(
        color: kPrimaryGreen,
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kPrimaryGreen))
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      _tabButton(0, Icons.flatware_rounded, 'My Recipes'),
                      _tabButton(1, Icons.article_rounded, 'My Posts'),
                      _tabButton(2, Icons.favorite_rounded, 'Liked'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_tabIndex == 0) ...[
                    if (_myRecipes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          AuthService.instance.isLoggedIn
                              ? 'No recipes yet.'
                              : 'Sign in to see your recipes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else ...[
                      ..._myRecipes.map(_recipeCard),
                      if (_myRecipesPage < _myRecipesLastPage)
                        Center(
                          child: TextButton(
                            onPressed: _myRecipesLoadingMore
                                ? null
                                : _loadMoreMyRecipes,
                            child: _myRecipesLoadingMore
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kPrimaryGreen,
                                    ),
                                  )
                                : const Text('Load more'),
                          ),
                        ),
                    ],
                  ] else if (_tabIndex == 1) ...[
                    if (!AuthService.instance.isLoggedIn)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Sign in to see your posts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else if (_myPosts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No posts yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else ...[
                      ..._myPosts.map(_postCard),
                      if (_myPostsPage < _myPostsLastPage)
                        Center(
                          child: TextButton(
                            onPressed:
                                _myPostsLoadingMore ? null : _loadMoreMyPosts,
                            child: _myPostsLoadingMore
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: kPrimaryGreen,
                                    ),
                                  )
                                : const Text('Load more'),
                          ),
                        ),
                    ],
                  ] else ...[
                    if (!AuthService.instance.isLoggedIn)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Sign in to see posts and recipes you\'ve liked.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else ...[
                      Builder(
                        builder: (context) {
                          final merged = mergeLikedActivityRows(
                            _likedHeartRecipes,
                            _likedHeartPosts,
                          );
                          if (merged.isEmpty) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No likes yet. Tap the heart on a recipe or post.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...merged.map(_likedCard),
                              if (_likedHeartRecipesPage <
                                      _likedHeartRecipesLastPage ||
                                  _likedHeartPostsPage <
                                      _likedHeartPostsLastPage)
                                Center(
                                  child: TextButton(
                                    onPressed: _likedHeartLoadingMore
                                        ? null
                                        : _loadMoreLikedHeart,
                                    child: _likedHeartLoadingMore
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: kPrimaryGreen,
                                            ),
                                          )
                                        : const Text('Load more'),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}
