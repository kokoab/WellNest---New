import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/post_service.dart';
import 'package:my_app/services/report_service.dart';
import 'package:my_app/screens/post_detail_screen.dart';
import 'package:my_app/widgets/wellnest_header.dart';
import 'package:my_app/widgets/initials_avatar.dart';
import 'package:my_app/services/saved_recipe_service.dart';
import 'package:my_app/services/vote_service.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  final ApiService _apiService = ApiService();
  List<Post> _posts = [];
  bool _loading = true;
  Object? _loadError;
  final Map<int, bool> _postLiked = {};
  final Map<int, int> _postLikesCount = {};
  final Map<int, int> _postCommentsCount = {};
  // Loading indicators per post
  final Map<int, bool> _liking = {};
  final Map<int, bool> _commenting = {};   // loading comments (expand)
  final Map<int, bool> _submitting = {};   // submitting a comment
  final Map<int, XFile?> _commentImages = {};
  CurrentUser? _currentUser;
  final Map<int, List<PostComment>> _postComments = {};
  final Map<int, bool> _commentsExpanded = {};
  final Map<int, TextEditingController> _commentControllers = {};

  @override
  void dispose() {
    for (final c in _commentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserThenPosts();
  }

  /// Load user first so isOwnPost and isLiked are correct when posts render.
  Future<void> _loadUserThenPosts() async {
    await _loadUser();
    await _loadPosts();
  }

  /// Fetch comment counts for all posts silently in the background.
  Future<void> _loadAllCommentCounts(List<Post> posts) async {
    for (final p in posts) {
      if (!mounted) return;
      try {
        final comments = await PostService.instance.fetchComments(p.id);
        if (mounted) {
          setState(() => _postCommentsCount[p.id] = comments.length);
        }
      } catch (_) {}
    }
  }

  /// Fetch like counts and liked state for all posts, same pattern as _loadAllCommentCounts.
  Future<void> _loadAllLikes(List<Post> posts) async {
    for (final p in posts) {
      if (!mounted) return;
      if (_liking[p.id] == true) continue; // skip if mid-interaction
      try {
        final result = await VoteService.instance.fetchPostLikes(p.id);
        if (mounted) {
          setState(() {
            _postLikesCount[p.id] = result.count;
            _postLiked[p.id] = result.isLiked;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadUser() async {
    if (AuthService.instance.isLoggedIn) {
      final u = await UserService.instance.fetchCurrentUser();
      if (mounted) setState(() => _currentUser = u);
    }
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final posts = await _apiService.fetchPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
        // Initialize with defaults — real values loaded by _loadAllLikes()
        for (final p in posts) {
          _postLiked[p.id] ??= false;
          _postLikesCount[p.id] ??= 0;
        }
      });
      // Load comment and like counts in background for all posts
      _loadAllCommentCounts(posts);
      _loadAllLikes(posts);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _posts.isEmpty) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator(color: Color(0xFF097333))),
      );
    }
    if (_loadError != null && _posts.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $_loadError', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _loadError = null);
                    _loadPosts();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final posts = _posts;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadUserThenPosts,
        color: wellGreen,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSpacing.gapV8,
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                        child: WellnestHeader(),
                      ),
                      AppSpacing.gapV16,
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.md),
                        child: Text(
                          'Feed',
                          style: TextStyle(
                            fontFamily: 'Recoleta',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      if (AuthService.instance.isLoggedIn) ...[
                        _buildCreatePostBox(),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (posts.isEmpty && !AuthService.instance.isLoggedIn)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No posts yet. Sign in to create one!')),
                ),
              )
            else if (posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No posts yet. Share something!')),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => RepaintBoundary(child: _buildFeedCard(posts[index])),
                    childCount: posts.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostBox() {
    var initials = _currentUser != null
        ? '${_currentUser!.firstName.isNotEmpty ? _currentUser!.firstName[0] : ''}${_currentUser!.lastName.isNotEmpty ? _currentUser!.lastName[0] : ''}'.toUpperCase().trim()
        : '?';
    if (initials.isEmpty) initials = '?';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _showCreatePostDialog,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFFFEECC),
                  backgroundImage: (_currentUser?.displayProfilePhotoUrl != null &&
                          _currentUser!.displayProfilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(_currentUser!.displayProfilePhotoUrl!)
                      : null,
                  child: (_currentUser?.displayProfilePhotoUrl == null ||
                          _currentUser!.displayProfilePhotoUrl!.isEmpty)
                      ? Text(
                          initials.isEmpty ? '?' : initials,
                          style: const TextStyle(
                            color: wellGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.imagePlaceholderGreen,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      "What's on your mind?",
                      style: TextStyle(
                        fontSize: 17,
                        color: kPrimaryGreen.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCreateAction(Icons.photo_library_outlined, 'Photo', nestOrange, _showCreatePostDialog),
              _buildCreateAction(Icons.restaurant_outlined, 'Recipe', wellGreen, _showCreatePostDialog),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreatePostDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreatePostSheet(
        apiService: _apiService,
        onPosted: () {
          _loadPosts();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post created!'), backgroundColor: wellGreen),
            );
          }
        },
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: nestOrange),
            );
          }
        },
      ),
    );
  }

  Widget _buildFeedCard(Post post) {
    final liked = _postLiked[post.id] ?? false;
    final isLiking = _liking[post.id] ?? false;
    final isCommenting = _commenting[post.id] ?? false;
    final expanded = _commentsExpanded[post.id] ?? false;
    final comments = _postComments[post.id] ?? [];
    // Use seeded counts, falling back to live comment list length when expanded
    final likesCount = _postLikesCount[post.id] ?? 0;
    final commentsCount = expanded ? comments.length : (_postCommentsCount[post.id] ?? 0);
    _commentControllers[post.id] ??= TextEditingController();

    void goToDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => PostDetailScreen(post: post),
        ),
      ).then((_) => _loadPosts()); // refresh counts on return
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: goToDetail,
                  child: InitialsAvatar(
                    name: post.userName,
                    size: 44,
                    imageUrl: post.userProfilePhotoUrl,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: goToDetail,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          formatPostTime(post.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
                if (post.recipeId != null)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (context) => RecipeDetailScreen(recipeId: post.recipeId!),
                      ),
                    ).then((_) => _loadPosts()),
                    style: TextButton.styleFrom(
                      foregroundColor: wellGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: wellGreen, width: 1),
                      ),
                    ),
                    child: const Text(
                      'View Recipe',
                      style: TextStyle(color: wellGreen, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // ── Text content ────────────────────────────────────────────────
          GestureDetector(
            onTap: goToDetail,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      post.content,
                      style: const TextStyle(fontSize: 15, height: 1.45),
                    ),
                  ),

                // ── Full-bleed image ─────────────────────────────────────
                if (post.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: post.content.isEmpty
                        ? const BorderRadius.vertical(top: Radius.circular(20))
                        : BorderRadius.zero,
                    child: Image.network(
                      post.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      cacheWidth: 800,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.imagePlaceholderGreen,
                        height: 200,
                        child: Icon(Icons.restaurant_menu, size: 48, color: wellGreen),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Actions ─────────────────────────────────────────────────────
          if (AuthService.instance.isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: [
                  // Like button
                  _ActionButton(
                    onTap: isLiking ? null : () => _toggleLike(post.id),
                    loading: isLiking,
                    icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: likesCount > 0 ? 'Like ($likesCount)' : (liked ? 'Liked' : 'Like'),
                    color: nestOrange,
                    filled: liked,
                  ),
                  const SizedBox(width: 4),
                  // Comment button with loading indicator
                  _ActionButton(
                    onTap: isCommenting ? null : () => _toggleComments(post.id),
                    loading: isCommenting,
                    icon: expanded ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                    label: commentsCount > 0 ? 'Comment ($commentsCount)' : 'Comment',
                    color: wellGreen,
                    filled: expanded,
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.black38, size: 22),
                    onSelected: (v) => v == 'report' ? _reportPost(post.id) : null,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'report', child: Text('Report')),
                    ],
                  ),
                ],
              ),
            ),

            // ── Comments ──────────────────────────────────────────────────
            if (expanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comments.isNotEmpty) ...[
                      Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
                      const SizedBox(height: 10),
                      ...comments.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InitialsAvatar(
                                  name: c.userName,
                                  size: 28,
                                  imageUrl: c.userProfilePhotoUrl,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (c.comment.isNotEmpty)
                                          RichText(
                                            text: TextSpan(
                                              style: const TextStyle(color: Colors.black87, fontSize: 13),
                                              children: [
                                                TextSpan(
                                                  text: '${c.userName}  ',
                                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                                TextSpan(text: c.comment),
                                              ],
                                            ),
                                          ),
                                        if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[
                                          if (c.comment.isNotEmpty) const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(
                                              c.imageUrl!,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 4),
                    ],
                    // Add comment row
                    _buildCommentInput(post.id, _submitting[post.id] ?? false),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 8),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _toggleLike(int postId) async {
    if (_liking[postId] == true) return;
    setState(() => _liking[postId] = true);
    try {
      final liked = _postLiked[postId] ?? false;
      if (liked) {
        await VoteService.instance.unlikePost(postId);
        if (mounted) setState(() {
          _postLiked[postId] = false;
          _postLikesCount[postId] = ((_postLikesCount[postId] ?? 1) - 1).clamp(0, 999999);
        });
      } else {
        await VoteService.instance.likePost(postId);
        if (mounted) setState(() {
          _postLiked[postId] = true;
          _postLikesCount[postId] = (_postLikesCount[postId] ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _liking[postId] = false);
    }
  }

  Future<void> _toggleComments(int postId) async {
    final expanded = _commentsExpanded[postId] ?? false;
    if (!expanded) {
      setState(() => _commenting[postId] = true);
      try {
        final comments = await PostService.instance.fetchComments(postId);
        if (mounted) setState(() {
          _commentsExpanded[postId] = true;
          _postComments[postId] = comments;
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load comments. Please try again.'), backgroundColor: nestOrange),
        );
        setState(() {
          _commentsExpanded[postId] = true;
          _postComments[postId] = const [];
        });
      } finally {
        if (mounted) setState(() => _commenting[postId] = false);
      }
    } else {
      if (mounted) setState(() => _commentsExpanded[postId] = false);
    }
  }

  Widget _buildCommentInput(int postId, bool isCommenting) {
    final pendingImage = _commentImages[postId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview
        if (pendingImage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FutureBuilder<List<int>>(
                    future: pendingImage.readAsBytes().then((b) => b.toList()),
                    builder: (_, snap) => snap.hasData
                        ? Image.memory(
                            Uint8List.fromList(snap.data!),
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(height: 100),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _commentImages[postId] = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            // Image pick button
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final x = await picker.pickImage(source: ImageSource.gallery);
                if (x != null && mounted) setState(() => _commentImages[postId] = x);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: nestOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_outlined, color: nestOrange, size: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _commentControllers[postId],
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              height: 36,
              child: isCommenting
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: wellGreen),
                    )
                  : IconButton(
                      onPressed: () => _addComment(postId),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.send_rounded, color: wellGreen, size: 22),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _addComment(int postId) async {
    final ctrl = _commentControllers[postId];
    final image = _commentImages[postId];
    if ((ctrl == null || ctrl.text.trim().isEmpty) && image == null) return;
    setState(() => _submitting[postId] = true);
    try {
      final comment = await PostService.instance.addComment(
        postId,
        ctrl?.text ?? '',
        image: image,
      );
      if (comment != null && mounted) {
        ctrl?.clear();
        setState(() {
          _commentImages[postId] = null;
          _postComments[postId] = [...(_postComments[postId] ?? []), comment];
          _postCommentsCount[postId] = (_postCommentsCount[postId] ?? 0) + 1;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting[postId] = false);
    }
  }

  Future<void> _reportPost(int postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Report this post to moderators?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ReportService.instance.reportPost(postId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

// ── Reusable action button with loading state ──────────────────────────────

class _ActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const _ActionButton({
    required this.onTap,
    required this.loading,
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Post Sheet ──────────────────────────────────────────────────────

class _CreatePostSheet extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onPosted;
  final void Function(String) onError;

  const _CreatePostSheet({
    required this.apiService,
    required this.onPosted,
    required this.onError,
  });

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const int _maxImageBytes = 5 * 1024 * 1024; // Backend limit (5MB)

  final TextEditingController _controller = TextEditingController();
  XFile? _selectedImage;
  Recipe? _selectedRecipe;
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickRecipeFromSaved() async {
    if (!AuthService.instance.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to attach a recipe')),
      );
      return;
    }
    try {
      final data = await SavedRecipeService.instance.fetchSavedRecipes();
      if (!mounted) return;
      final recipes = data.recipes;
      if (recipes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save some recipes first to attach them here')),
        );
        return;
      }
      final picked = await Navigator.push<Recipe>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (ctx) => _PickRecipePage(recipes: recipes),
        ),
      );
      if (picked != null && mounted) setState(() => _selectedRecipe = picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (x != null && mounted) setState(() => _selectedImage = x);
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    if (_posting) return;
    setState(() => _posting = true);
    try {
      if (_selectedImage != null) {
        final length = await _selectedImage!.length();
        if (length > _maxImageBytes) {
          throw Exception('Image is too large. Please choose one under 5MB.');
        }
      }

      final post = await widget.apiService.createPost(
        content: content,
        recipeId: _selectedRecipe?.id,
      );
      if (_selectedImage != null) {
        await widget.apiService.uploadPostImage(post.id, _selectedImage!);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onPosted();
    } catch (e) {
      if (mounted) {
        setState(() => _posting = false);
        widget.onError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Post',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: wellGreen),
                ),
                IconButton(
                  onPressed: _posting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: nestOrange),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 4,
              autofocus: true,
              enabled: !_posting,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(color: wellGreen.withOpacity(0.5), fontSize: 17),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_selectedRecipe != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEECC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: wellGreen.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.restaurant, color: wellGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedRecipe!.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1a1a1a),
                            ),
                          ),
                          Text(
                            '${_selectedRecipe!.prepTime} min',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _posting ? null : () => setState(() => _selectedRecipe = null),
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
            ],
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImagePreview(_selectedImage!),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: _posting ? null : () => setState(() => _selectedImage = null),
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _posting ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, color: nestOrange, size: 24),
                  label: const Text('Add Photo', style: TextStyle(color: nestOrange, fontWeight: FontWeight.w600)),
                ),
                if (AuthService.instance.isLoggedIn)
                  TextButton.icon(
                    onPressed: _posting ? null : _pickRecipeFromSaved,
                    icon: Icon(Icons.bookmark_outline, color: wellGreen, size: 24),
                    label: Text(
                      _selectedRecipe != null ? 'Change Recipe' : 'Attach Recipe',
                      style: TextStyle(color: wellGreen, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _posting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: wellGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _posting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(XFile file) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 180,
            color: AppColors.imagePlaceholderGreen,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Image.memory(
          snapshot.data!,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _PickRecipePage extends StatelessWidget {
  final List<Recipe> recipes;

  const _PickRecipePage({required this.recipes});

  static const Color _wellGreen = Color(0xFF097333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attach recipe from saved'),
        backgroundColor: _wellGreen,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 26),
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: recipes.length,
        itemBuilder: (_, i) {
          final r = recipes[i];
          return ListTile(
            leading: r.displayImageUrl != null && r.displayImageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(r.displayImageUrl!, width: 48, height: 48, fit: BoxFit.cover, cacheWidth: 96, cacheHeight: 96),
                  )
                : Icon(Icons.restaurant, color: _wellGreen),
            title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${r.prepTime} min'),
            onTap: () => Navigator.pop(context, r),
          );
        },
      ),
    );
  }
}