part of 'package:my_app/screens/admin_dashboard.dart';

class _WebModal extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _WebModal({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final modalWidth = (screenSize.width * 0.88).clamp(340.0, 760.0);
    final modalMaxHeight = screenSize.height * 0.84;
    final cardBg = isDark ? const Color(0xFF1C1C1C) : Colors.white;
    final outline = wellnestOutlineColor(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: modalWidth,
          maxHeight: modalMaxHeight,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outline, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: outline, width: 0.5),
                        ),
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(height: 0.5, color: outline),
              // Scrollable body
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: child,
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

// ─── Modal shared states ──────────────────────────────────────────────────────
class _ModalLoading extends StatelessWidget {
  const _ModalLoading();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(
      child: CircularProgressIndicator(color: kPrimaryGreen, strokeWidth: 2),
    ),
  );
}

class _ModalError extends StatelessWidget {
  final String message;
  const _ModalError({required this.message});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        message.replaceFirst('Exception: ', ''),
        style: const TextStyle(color: kAccentOrange, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _ModalEmpty extends StatelessWidget {
  final String message;
  const _ModalEmpty({required this.message});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Posts Modal Content ──────────────────────────────────────────────────────
class _PostsModalContent extends StatefulWidget {
  final int userId;
  const _PostsModalContent({required this.userId});

  @override
  State<_PostsModalContent> createState() => _PostsModalContentState();
}

class _PostsModalContentState extends State<_PostsModalContent> {
  static const int _perPage = 10;
  final List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final response = await ApiService().fetchPostsPaginated(
        userId: widget.userId,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(response.posts);
        _page = response.currentPage;
        _hasMore = response.currentPage < response.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _adminErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final response = await ApiService().fetchPostsPaginated(
        userId: widget.userId,
        page: _page + 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      final existing = _posts.map((p) => p.id).toSet();
      final incoming = response.posts
          .where((p) => !existing.contains(p.id))
          .toList();
      setState(() {
        _posts.addAll(incoming);
        _page = response.currentPage;
        _hasMore = response.currentPage < response.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (_loading) return const _ModalLoading();
    if (_error != null) return _ModalError(message: _error!);
    if (_posts.isEmpty) {
      return const _ModalEmpty(
        message: 'This user has not created any posts yet.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...List.generate(_posts.length, (i) {
          final post = _posts[i];
          final cardBg = isDark
              ? const Color(0xFF252525)
              : const Color(0xFFF9F9F9);
          final borderColor = isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06);
          return Padding(
            padding: EdgeInsets.only(bottom: i == _posts.length - 1 ? 0 : 10),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 0.5),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content.isEmpty ? 'No text content' : post.content,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                  if (post.displayImageUrl != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        post.displayImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 160,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Image unavailable',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.commentsCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        post.createdAt != null
                            ? post.createdAt!.split('T').first
                            : 'Unknown',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (_hasMore) ...[
          const SizedBox(height: 10),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'Loading…' : 'Load more posts'),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Comments Modal Content ───────────────────────────────────────────────────
class _CommentsModalContent extends StatefulWidget {
  final AdminUser user;
  const _CommentsModalContent({required this.user});
  @override
  State<_CommentsModalContent> createState() => _CommentsModalContentState();
}

class _CommentsModalContentState extends State<_CommentsModalContent> {
  final Map<int, Future<PostCommentsResponse>> _commentFutures = {};
  int? _expandedPostId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<PostListResponse>(
      future: ApiService().fetchPostsPaginated(
        userId: widget.user.id,
        page: 1,
        perPage: 20,
      ),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _ModalLoading();
        if (snapshot.hasError)
          return _ModalError(message: snapshot.error.toString());
        final posts = snapshot.data?.posts ?? [];
        if (posts.isEmpty)
          return const _ModalEmpty(
            message: 'This user has no posts to show comments for.',
          );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(posts.length, (i) {
            final post = posts[i];
            final isExpanded = _expandedPostId == post.id;
            final cardBg = isDark
                ? const Color(0xFF252525)
                : const Color(0xFFF9F9F9);
            final borderColor = isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06);

            return Padding(
              padding: EdgeInsets.only(bottom: i == posts.length - 1 ? 0 : 10),
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post header row
                    InkWell(
                      onTap: () => setState(() {
                        if (isExpanded) {
                          _expandedPostId = null;
                        } else {
                          _expandedPostId = post.id;
                          _commentFutures[post.id] ??= PostService.instance
                              .fetchCommentsPaginated(
                                post.id,
                                page: 1,
                                perPage: 20,
                              );
                        }
                      }),
                      borderRadius: isExpanded
                          ? const BorderRadius.vertical(
                              top: Radius.circular(12),
                            )
                          : BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.content.isEmpty
                                        ? 'Untitled post'
                                        : post.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${post.commentsCount} comment${post.commentsCount == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: kPrimaryGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                isExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 16,
                                color: kPrimaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Expanded comments
                    if (isExpanded) ...[
                      Divider(height: 0.5, color: borderColor),
                      FutureBuilder<PostCommentsResponse>(
                        future: _commentFutures[post.id],
                        builder: (ctx, cs) {
                          if (cs.connectionState != ConnectionState.done)
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: kPrimaryGreen,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          if (cs.hasError)
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                cs.error.toString(),
                                style: const TextStyle(
                                  color: kAccentOrange,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          final comments = cs.data?.comments ?? [];
                          if (comments.isEmpty)
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No comments on this post yet.',
                                style: TextStyle(fontSize: 12),
                              ),
                            );
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: comments.map((comment) {
                                final cBg = isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: cBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _UserAvatar(name: comment.userName),
                                          const SizedBox(width: 8),
                                          Text(
                                            comment.userName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            comment.createdAt.isEmpty
                                                ? 'Unknown'
                                                : comment.createdAt
                                                      .split('T')
                                                      .first,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (comment.comment.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          comment.comment,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      if (comment.imageUrl != null) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            comment.imageUrl!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 100,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => Container(
                                                  height: 40,
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.04,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.04,
                                                        ),
                                                  child: Center(
                                                    child: Text(
                                                      'Image unavailable',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Recipes Modal Content ────────────────────────────────────────────────────
class _RecipesModalContent extends StatefulWidget {
  final int userId;
  const _RecipesModalContent({required this.userId});
  @override
  State<_RecipesModalContent> createState() => _RecipesModalContentState();
}

class _RecipesModalContentState extends State<_RecipesModalContent> {
  bool _cardView = true; // toggle: card vs list
  final List<Recipe> _recipes = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final response = await RecipeService.instance.fetchRecipes(
        userId: widget.userId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(response.recipes);
        _page = response.currentPage;
        _hasMore = response.currentPage < response.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _adminErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final response = await RecipeService.instance.fetchRecipes(
        userId: widget.userId,
        page: _page + 1,
      );
      if (!mounted) return;
      final existing = _recipes.map((r) => r.id).toSet();
      final incoming = response.recipes
          .where((r) => !existing.contains(r.id))
          .toList();
      setState(() {
        _recipes.addAll(incoming);
        _page = response.currentPage;
        _hasMore = response.currentPage < response.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (_loading) return const _ModalLoading();
    if (_error != null) return _ModalError(message: _error!);
    if (_recipes.isEmpty) {
      return const _ModalEmpty(
        message: 'This user has not created any recipes yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${_recipes.length} recipe${_recipes.length == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            _ViewToggle(
              isCard: _cardView,
              onChanged: (v) => setState(() => _cardView = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_cardView)
          _RecipeCardGrid(recipes: _recipes, isDark: isDark, theme: theme)
        else
          _RecipeListView(recipes: _recipes, isDark: isDark, theme: theme),
        if (_hasMore) ...[
          const SizedBox(height: 10),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'Loading…' : 'Load more recipes'),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Single recipe preview (e.g. admin recipe management) ────────────────────
class _RecipePreviewModalContent extends StatefulWidget {
  final int recipeId;
  const _RecipePreviewModalContent({required this.recipeId});

  @override
  State<_RecipePreviewModalContent> createState() =>
      _RecipePreviewModalContentState();
}

class _RecipePreviewModalContentState extends State<_RecipePreviewModalContent> {
  Recipe? _recipe;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await RecipeService.instance.fetchRecipe(widget.recipeId);
      if (!mounted) return;
      setState(() {
        _recipe = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _adminErrorMessage(e);
        _loading = false;
      });
    }
  }

  String? _heroImageUrl(Recipe r) {
    final urls = r.galleryDisplayUrls;
    if (urls.isNotEmpty) return urls.first;
    return r.displayImageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (_loading) return const _ModalLoading();
    if (_error != null) return _ModalError(message: _error!);
    final recipe = _recipe;
    if (recipe == null) {
      return const _ModalEmpty(message: 'Recipe could not be loaded.');
    }

    final cardBg = isDark ? const Color(0xFF252525) : const Color(0xFFF9F9F9);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    final heroUrl = _heroImageUrl(recipe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (heroUrl != null)
                Image.network(
                  heroUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _RecipeImagePlaceholder(isDark: isDark, theme: theme),
                )
              else
                SizedBox(
                  height: 140,
                  child: _RecipeImagePlaceholder(isDark: isDark, theme: theme),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (recipe.category?.name.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              recipe.category!.name,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryGreen,
                              ),
                            ),
                          ),
                        Text(
                          'By ${recipe.userDisplayName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (recipe.createdAt != null)
                          Text(
                            _formatHumanDate(recipe.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (recipe.prepTime > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe.prepTime} min',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        if (recipe.viewsCount != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${recipe.viewsCount} views',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        if (recipe.averageRating != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFE6930A),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${recipe.averageRating!.toStringAsFixed(1)} (${recipe.ratingsCount ?? 0})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE6930A),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (recipe.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      Text(
                        recipe.description!.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (recipe.ingredients != null && recipe.ingredients!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Ingredients',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          ...recipe.ingredients!.map(
            (ing) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      ing.displayLine,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (recipe.steps != null && recipe.steps!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            recipe.prepTimingMode == PrepTimingMode.perStep
                ? 'Steps'
                : 'Instructions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          ...recipe.steps!.asMap().entries.map((e) {
            final i = e.key;
            final step = e.value;
            final n = i + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.displayTitle(n),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (step.instructions?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        step.instructions!.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (step.prepTimeMinutes != null &&
                        step.prepTimeMinutes! > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${step.prepTimeMinutes} min',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ] else if (recipe.instructions.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Instructions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipe.instructions.trim(),
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── View toggle button ───────────────────────────────────────────────────────
class _ViewToggle extends StatelessWidget {
  final bool isCard;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.isCard, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleBtn(
            icon: Icons.grid_view_rounded,
            active: isCard,
            onTap: () => onChanged(true),
            tooltip: 'Card view',
          ),
          const SizedBox(width: 2),
          _ToggleBtn(
            icon: Icons.view_list_rounded,
            active: !isCard,
            onTap: () => onChanged(false),
            tooltip: 'List view',
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;
  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            icon,
            size: 14,
            color: active
                ? kPrimaryGreen
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Recipe Card Grid ─────────────────────────────────────────────────────────
class _RecipeCardGrid extends StatelessWidget {
  final List<Recipe> recipes;
  final bool isDark;
  final ThemeData theme;
  const _RecipeCardGrid({
    required this.recipes,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive: 2 columns on wide modal, 1 on narrow
    final width = MediaQuery.sizeOf(context).width;
    final cols = width >= 600 ? 2 : 1;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    final cardBg = isDark ? const Color(0xFF252525) : const Color(0xFFF9F9F9);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final colWidth = (constraints.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: recipes.map((recipe) {
            final imageUrl = recipe.displayImageUrl;
            final rating = recipe.averageRating;
            final ratingsCount = recipe.ratingsCount ?? 0;
            final category = recipe.category?.name;

            return SizedBox(
              width: colWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _RecipeImagePlaceholder(
                                    isDark: isDark,
                                    theme: theme,
                                  ),
                            )
                          : _RecipeImagePlaceholder(
                              isDark: isDark,
                              theme: theme,
                            ),
                    ),
                    // Info
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: kPrimaryGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: kPrimaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              height: 1.3,
                            ),
                          ),
                          if (recipe.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              recipe.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (rating != null) ...[
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Color(0xFFE6930A),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE6930A),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '($ratingsCount)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (recipe.prepTime > 0) ...[
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${recipe.prepTime} min',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─── Recipe List View ─────────────────────────────────────────────────────────
class _RecipeListView extends StatelessWidget {
  final List<Recipe> recipes;
  final bool isDark;
  final ThemeData theme;
  const _RecipeListView({
    required this.recipes,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);
    final cardBg = isDark ? const Color(0xFF252525) : const Color(0xFFF9F9F9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(recipes.length, (i) {
        final recipe = recipes[i];
        final imageUrl = recipe.displayImageUrl;
        final rating = recipe.averageRating;
        final ratingsCount = recipe.ratingsCount ?? 0;
        final category = recipe.category?.name;

        return Padding(
          padding: EdgeInsets.only(bottom: i == recipes.length - 1 ? 0 : 8),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12),
                  ),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _RecipeImagePlaceholder(
                                  isDark: isDark,
                                  theme: theme,
                                  small: true,
                                ),
                          )
                        : _RecipeImagePlaceholder(
                            isDark: isDark,
                            theme: theme,
                            small: true,
                          ),
                  ),
                ),
                // Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (category != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: kPrimaryGreen.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: kPrimaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (recipe.prepTime > 0)
                              Text(
                                '${recipe.prepTime} min',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (recipe.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            recipe.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (rating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFFE6930A),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE6930A),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '($ratingsCount)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _RecipeImagePlaceholder extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool small;
  const _RecipeImagePlaceholder({
    required this.isDark,
    required this.theme,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.black.withValues(alpha: 0.04),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_outlined,
          size: small ? 20 : 28,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
