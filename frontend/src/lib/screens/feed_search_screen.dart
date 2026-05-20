import 'package:flutter/material.dart';
import 'package:wellnest/models/post.dart';
import 'package:wellnest/screens/post_detail_screen.dart';
import 'package:wellnest/screens/recipe_detail_screen.dart';
import 'package:wellnest/screens/user_profile_screen.dart';
import 'package:wellnest/services/api_service.dart';
import 'package:wellnest/services/search_history_service.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/initials_avatar.dart';

/// Full-screen search for the feed; respects [followingOnly] (following vs global feed).
class FeedSearchScreen extends StatefulWidget {
  const FeedSearchScreen({super.key, required this.followingOnly});

  final bool followingOnly;

  @override
  State<FeedSearchScreen> createState() => _FeedSearchScreenState();
}

class _FeedSearchScreenState extends State<FeedSearchScreen> {
  static const Color wellGreen = Color(0xFF097333);

  final ApiService _api = ApiService();
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Post> _popular = [];
  List<Post> _results = [];
  List<String> _recent = [];
  bool _loadingPopular = true;
  Object? _popularError;
  bool _loadingResults = false;
  bool _loadingMore = false;
  bool _resultsMode = false;
  String? _resultsQuery;
  int _resultsPage = 1;
  bool _hasMoreResults = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadRecent(), _loadPopular()]);
  }

  Future<void> _loadRecent() async {
    final r = await SearchHistoryService.instance.recent(SearchHistoryArea.feed);
    if (mounted) setState(() => _recent = r);
  }

  Future<void> _loadPopular() async {
    setState(() {
      _loadingPopular = true;
      _popularError = null;
    });
    try {
      final res = await _api.fetchPostsPaginated(
        followingOnly: widget.followingOnly,
        page: 1,
        perPage: 10,
        sort: 'popular',
      );
      if (!mounted) return;
      setState(() {
        _popular = res.posts;
        _loadingPopular = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _popularError = e;
        _loadingPopular = false;
      });
    }
  }

  void _onScroll() {
    if (!_resultsMode || !_hasMoreResults || _loadingResults || _loadingMore) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _loadMoreResults();
    }
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    await SearchHistoryService.instance.record(SearchHistoryArea.feed, q);
    await _loadRecent();
    if (!mounted) return;
    setState(() {
      _resultsMode = true;
      _loadingResults = true;
      _results = [];
      _resultsQuery = q;
      _resultsPage = 1;
      _hasMoreResults = false;
    });
    try {
      final res = await _api.fetchPostsPaginated(
        followingOnly: widget.followingOnly,
        page: 1,
        perPage: 15,
        search: q,
      );
      if (!mounted) return;
      setState(() {
        _results = res.posts;
        _loadingResults = false;
        _resultsPage = res.currentPage;
        _hasMoreResults = res.currentPage < res.lastPage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingResults = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _loadMoreResults() async {
    final q = _resultsQuery;
    if (q == null || q.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _resultsPage + 1;
      final res = await _api.fetchPostsPaginated(
        followingOnly: widget.followingOnly,
        page: next,
        perPage: 15,
        search: q,
      );
      if (!mounted) return;
      setState(() {
        _results.addAll(res.posts);
        _resultsPage = res.currentPage;
        _hasMoreResults = res.currentPage < res.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _clearSearch() {
    _queryController.clear();
    setState(() {
      _resultsMode = false;
      _results = [];
      _resultsQuery = null;
    });
  }

  void _openPost(Post post) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => PostDetailScreen(post: post),
      ),
    );
  }

  void _openProfile(Post post) {
    if (post.userId == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen(userId: post.userId!),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.followingOnly ? 'Search following' : 'Search feed',
          style: georgiaProTextStyle(
            fontSize: 18,
            color: AppColors.primaryGreen,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: widget.followingOnly
                      ? 'Search posts from people you follow'
                      : 'Search posts, authors, recipes…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {});
                            _clearSearch();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: _runSearch,
              ),
            ),
          ),
          if (!_resultsMode) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Popular right now',
                  style: wellnestPageTitleStyleFor(context).copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildPopularSection(colorScheme)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recent searches',
                  style: wellnestPageTitleStyleFor(context).copyWith(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(child: _buildRecentSection()),
            ),
          ] else ...[
            if (_loadingResults && _results.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: wellGreen),
                ),
              )
            else if (_results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No posts match “${_resultsQuery ?? ''}”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= _results.length) {
                        if (!_loadingMore) return const SizedBox.shrink();
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: wellGreen,
                              ),
                            ),
                          ),
                        );
                      }
                      final post = _results[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PostSearchTile(
                          post: post,
                          onOpenPost: () => _openPost(post),
                          onOpenProfile: () => _openProfile(post),
                          onRecipe: post.recipeId != null
                              ? () {
                                  Navigator.push<void>(
                                    context,
                                    MaterialPageRoute<void>(
                                      fullscreenDialog: true,
                                      builder: (context) => RecipeDetailScreen(
                                        recipeId: post.recipeId!,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      );
                    },
                    childCount: _results.length + (_loadingMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPopularSection(ColorScheme colorScheme) {
    if (_loadingPopular) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: wellGreen)),
      );
    }
    if (_popularError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              'Could not load popular posts.',
              style: TextStyle(color: colorScheme.error),
            ),
            TextButton(onPressed: _loadPopular, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_popular.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          widget.followingOnly
              ? 'No posts from people you follow yet.'
              : 'No posts yet.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return SizedBox(
      height: 158,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _popular.length,
        itemBuilder: (context, i) {
          final post = _popular[i];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 272,
              child: Material(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openPost(post),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            post.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${post.likesCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSection() {
    if (_recent.isEmpty) {
      return Text(
        'Your recent searches will appear here.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _recent.map((q) {
        return ActionChip(
          label: Text(q),
          onPressed: () {
            _queryController.text = q;
            setState(() {});
            _runSearch(q);
          },
        );
      }).toList(),
    );
  }
}

class _PostSearchTile extends StatelessWidget {
  const _PostSearchTile({
    required this.post,
    required this.onOpenPost,
    required this.onOpenProfile,
    this.onRecipe,
  });

  final Post post;
  final VoidCallback onOpenPost;
  final VoidCallback onOpenProfile;
  final VoidCallback? onRecipe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: wellnestCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onOpenProfile,
                  child: InitialsAvatar(
                    name: post.userName,
                    size: 40,
                    imageUrl: post.displayAuthorProfilePhotoUrl,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${post.likesCount} likes · ${post.commentsCount} comments',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (onRecipe != null)
                  TextButton(
                    onPressed: onRecipe,
                    child: Text(
                      'Recipe',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onOpenPost,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                post.content,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
