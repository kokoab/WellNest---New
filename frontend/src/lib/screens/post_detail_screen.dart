import 'package:flutter/material.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/screens/user_profile_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/post_service.dart';
import 'package:my_app/services/user_service.dart';
import 'package:my_app/screens/edit_post_screen.dart';
import 'package:my_app/widgets/post_photo_collage.dart';
import 'package:my_app/widgets/full_screen_photo_gallery.dart';
import 'package:my_app/widgets/wellnest_popup_menu.dart';
import 'package:my_app/services/report_service.dart';
import 'package:my_app/services/vote_service.dart';
import 'package:my_app/widgets/initials_avatar.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  bool _liked = false;
  List<PostComment> _comments = [];
  bool _commentsLoaded = false;
  bool _loadingMoreComments = false;
  bool _commentsHasMore = true;
  int _commentsPage = 1;
  /// Total comment count from the API (pagination `total`); kept in sync when adding.
  int _commentsTotal = 0;
  static const int _commentsPerPage = 10;
  static const double _loadMoreCommentsScrollThreshold = 280;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();

  /// Used when [AuthService.userId] is missing (older sessions) so owner menu still shows.
  CurrentUser? _currentUserMe;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _commentsTotal = widget.post.commentsCount;
    _scrollController.addListener(_onCommentsScroll);
    _refreshPost();
    _loadComments();
    _loadCurrentUserForOwnership();
  }

  Future<void> _loadCurrentUserForOwnership() async {
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final me = await UserService.instance.fetchCurrentUser();
      if (mounted) setState(() => _currentUserMe = me);
    } catch (_) {
      // Menu falls back to AuthService.userId only.
    }
  }

  bool _ownsThisPost() {
    final authorId = _post.userId;
    if (authorId == null) return false;
    final tokenUid = AuthService.instance.userId;
    if (tokenUid != null && tokenUid == authorId) return true;
    final meId = _currentUserMe?.id;
    if (meId != null && meId == authorId) return true;
    return false;
  }

  void _openAuthorProfile() {
    final id = _post.userId;
    if (id == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => UserProfileScreen(userId: id),
      ),
    );
  }

  /// Same full-screen gallery UX as [RecipeDetailScreen] hero photos.
  void _openPostPhotoGallery({int initialIndex = 0}) {
    final urls = _post.galleryDisplayUrls;
    if (urls.isEmpty) return;
    final start = initialIndex.clamp(0, urls.length - 1);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => FullScreenPhotoGallery(
          urls: urls,
          initialIndex: start,
        ),
      ),
    );
  }

  Future<void> _refreshPost() async {
    try {
      final fresh = await PostService.instance.fetchPost(widget.post.id);
      if (mounted) {
        setState(() {
          _post = fresh;
          _commentsTotal = fresh.commentsCount;
        });
      }
    } catch (_) {
      // Keep navigation payload if offline / error.
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onCommentsScroll);
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentsScroll() {
    if (!_commentsLoaded || !_commentsHasMore || _loadingMoreComments) return;
    final position = _scrollController.position;
    if (!position.hasViewportDimension || position.maxScrollExtent <= 0) return;
    if (position.pixels >=
        position.maxScrollExtent - _loadMoreCommentsScrollThreshold) {
      _loadMoreComments();
    }
  }

  /// If the page is tall enough that the list does not scroll, still fetch more
  /// comments until the user can scroll or the API has no next page.
  void _scheduleFillViewportIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_commentsLoaded || !_commentsHasMore || _loadingMoreComments) return;
      if (!_scrollController.hasClients) {
        _scheduleFillViewportIfShort();
        return;
      }
      final position = _scrollController.position;
      if (!position.hasViewportDimension) return;
      if (position.maxScrollExtent > _loadMoreCommentsScrollThreshold) return;
      await _loadMoreComments();
      if (mounted) _scheduleFillViewportIfShort();
    });
  }

  Future<void> _loadComments() async {
    try {
      final response = await PostService.instance.fetchCommentsPaginated(
        _post.id,
        page: 1,
        perPage: _commentsPerPage,
      );
      if (mounted) {
        setState(() {
          _comments = response.comments;
          _commentsPage = response.currentPage;
          _commentsHasMore = response.currentPage < response.lastPage;
          _commentsTotal = response.total;
          _commentsLoaded = true;
        });
        _scheduleFillViewportIfShort();
      }
    } catch (_) {
      if (mounted) setState(() => _commentsLoaded = true);
    }
  }

  Future<void> _loadMoreComments() async {
    if (_loadingMoreComments || !_commentsHasMore) return;
    setState(() => _loadingMoreComments = true);
    try {
      final response = await PostService.instance.fetchCommentsPaginated(
        _post.id,
        page: _commentsPage + 1,
        perPage: _commentsPerPage,
      );
      if (!mounted) return;
      final existing = _comments.map((c) => c.id).toSet();
      final incoming = response.comments
          .where((c) => !existing.contains(c.id))
          .toList();
      setState(() {
        _comments.addAll(incoming);
        _commentsPage = response.currentPage;
        _commentsHasMore = response.currentPage < response.lastPage;
        if (response.total > 0) _commentsTotal = response.total;
        _loadingMoreComments = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMoreComments = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    try {
      final comment = await PostService.instance.addComment(_post.id, text);
      if (comment != null && mounted) {
        _commentController.clear();
        setState(() {
          _comments = [..._comments, comment];
          _commentsTotal = _commentsTotal + 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added'),
            backgroundColor: kPrimaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  InputDecoration _commentFieldDecoration(BuildContext context) {
    final outline = wellnestOutlineColor(context);
    return InputDecoration(
      hintText: 'Add a comment...',
      hintStyle: TextStyle(
        color: kPrimaryGreen.withValues(alpha: 0.55),
        fontSize: 15,
        fontFamily: kFontHelveticaNow,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: kPrimaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fullscreen = ModalRoute.of(context)?.fullscreenDialog ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(
          'Post',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        backgroundColor: AppColors.backgroundCream,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: cs.onSurface, size: 26),
        leading: fullscreen
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
                onPressed: () => Navigator.maybePop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Main post
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post header: Avatar + User info + Options
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _post.userId != null
                                ? GestureDetector(
                                    onTap: _openAuthorProfile,
                                    child: InitialsAvatar(
                                      name: _post.userName,
                                      size: 48,
                                      imageUrl:
                                          _post.displayAuthorProfilePhotoUrl,
                                    ),
                                  )
                                : InitialsAvatar(
                                    name: _post.userName,
                                    size: 48,
                                    imageUrl:
                                        _post.displayAuthorProfilePhotoUrl,
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _post.userId != null
                                      ? GestureDetector(
                                          onTap: _openAuthorProfile,
                                          child: Text(
                                            _post.userName,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: kPrimaryGreen,
                                                  fontFamily:
                                                      kFontHelveticaNow,
                                                ),
                                          ),
                                        )
                                      : Text(
                                          _post.userName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: kPrimaryGreen,
                                                fontFamily: kFontHelveticaNow,
                                              ),
                                        ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatPostTime(_post.createdAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: kCaptionGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (AuthService.instance.isLoggedIn)
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                tooltip: 'More options',
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: kPrimaryGreen,
                                ),
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    final updated =
                                        await Navigator.push<Post>(
                                      context,
                                      MaterialPageRoute<Post>(
                                        builder: (context) =>
                                            EditPostScreen(post: _post),
                                      ),
                                    );
                                    if (updated != null && mounted) {
                                      setState(() => _post = updated);
                                    }
                                  } else if (v == 'delete') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete post'),
                                        content: const Text(
                                          'Remove this post permanently?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: kAccentOrange,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true && mounted) {
                                      try {
                                        await PostService.instance.deletePost(
                                          _post.id,
                                        );
                                        if (mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } else if (v == 'report') {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Report Post'),
                                        content: const Text(
                                          'Report this post to moderators?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Report'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      try {
                                        await ReportService.instance.reportPost(
                                          _post.id,
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Report submitted'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (context) {
                                  final owner = _ownsThisPost();
                                  return [
                                    if (owner) ...[
                                      wellnestPopupMenuItem(
                                        value: 'edit',
                                        icon: Icons.edit_outlined,
                                        label: 'Edit',
                                      ),
                                      wellnestPopupMenuItem(
                                        value: 'delete',
                                        icon: Icons.delete_outline_rounded,
                                        label: 'Delete',
                                        iconColor: kAccentOrange,
                                      ),
                                    ],
                                    if (!owner)
                                      wellnestPopupMenuItem(
                                        value: 'report',
                                        icon: Icons.flag_outlined,
                                        label: 'Report',
                                      ),
                                  ];
                                },
                              ),
                          ],
                        ),
                        // Main post content
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Text(
                            _post.content,
                            style: const TextStyle(
                              fontFamily: 'HelveticaNow',
                              fontSize: 18,
                              color: kBodyTextDark,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (_post.galleryDisplayUrls.isNotEmpty) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openPostPhotoGallery(),
                            child: PostPhotoCollage(
                              urls: _post.galleryDisplayUrls,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        // Action bar
                        Row(
                          children: [
                            if (AuthService.instance.isLoggedIn)
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    if (_liked) {
                                      await VoteService.instance.unlikePost(
                                        _post.id,
                                      );
                                      if (mounted)
                                        setState(() => _liked = false);
                                    } else {
                                      await VoteService.instance.likePost(
                                        _post.id,
                                      );
                                      if (mounted)
                                        setState(() => _liked = true);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(
                                  _liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: AppColors.accentOrange,
                                  size: 22,
                                ),
                                label: Text(
                                  _liked ? 'Liked' : 'Like',
                                  style: const TextStyle(
                                    color: AppColors.accentOrange,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: kFontHelveticaNow,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.accentOrange,
                                ),
                              ),
                            const Spacer(),
                            if (_post.recipeId != null)
                              Material(
                                color:
                                    AppColors.primaryGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      fullscreenDialog: true,
                                      builder: (context) => RecipeDetailScreen(
                                        recipeId: _post.recipeId!,
                                      ),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      'View Recipe',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: kPrimaryGreen,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: kFontHelveticaNow,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Divider between post and comments
                SliverToBoxAdapter(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: wellnestOutlineColor(context).withValues(alpha: 0.5),
                  ),
                ),
                // Comments header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      'Comments ($_commentsTotal)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: kPrimaryGreen,
                        fontFamily: kFontHelveticaNow,
                      ),
                    ),
                  ),
                ),
                // Comments list
                if (!_commentsLoaded)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(color: kPrimaryGreen),
                      ),
                    ),
                  )
                else if (_comments.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: SizedBox.shrink(),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final c = _comments[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.md,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InitialsAvatar(
                                  name: c.userName,
                                  size: 32,
                                  imageUrl: c.displayProfilePhotoUrl,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.userName,
                                        style: const TextStyle(
                                          fontFamily: 'HelveticaNow',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: kBodyTextDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        c.comment,
                                        style: const TextStyle(
                                          fontFamily: 'HelveticaNow',
                                          fontSize: 14,
                                          color: kBodyTextDark,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (index < _comments.length - 1)
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.grey[300],
                            ),
                        ],
                      );
                    }, childCount: _comments.length),
                  ),
                if (_commentsLoaded &&
                    _commentsHasMore &&
                    _loadingMoreComments)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 28),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: kPrimaryGreen,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Anchored reply input
          if (AuthService.instance.isLoggedIn)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCream,
                  border: Border(
                    top: BorderSide(color: wellnestOutlineColor(context), width: 1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: theme.textTheme.bodyLarge,
                        decoration: _commentFieldDecoration(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: kPrimaryGreen,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _addComment,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
