import 'package:flutter/material.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/post_service.dart';
import 'package:my_app/services/report_service.dart';
import 'package:my_app/services/vote_service.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  late Post _post;
  bool _liked = false;
  List<PostComment> _comments = [];
  bool _commentsLoaded = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await PostService.instance.fetchComments(_post.id);
      if (mounted) setState(() {
        _comments = comments;
        _commentsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoaded = true);
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    try {
      final comment = await PostService.instance.addComment(_post.id, text);
      if (comment != null && mounted) {
        _commentController.clear();
        setState(() => _comments = [..._comments, comment]);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added'), backgroundColor: wellGreen),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: wellGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Main post
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Post header: Avatar + User info + Options
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFF9BD21).withOpacity(0.3),
                              child: Text(
                                _getInitials(_post.userName),
                                style: const TextStyle(
                                  color: wellGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post.userName,
                                    style: const TextStyle(
                                      fontFamily: 'Recoleta',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: wellGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '2 hours ago',
                                    style: TextStyle(
                                      fontFamily: 'HelveticaNow',
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (AuthService.instance.isLoggedIn)
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                                onSelected: (v) async {
                                  if (v == 'report') {
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
                                    if (ok == true) {
                                      try {
                                        await ReportService.instance.reportPost(_post.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Report submitted')),
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
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'report', child: Text('Report')),
                                ],
                              ),
                          ],
                        ),
                        // Main post content
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
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
                        if (_post.imageUrl.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _post.imageUrl,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.imagePlaceholderGreen,
                                height: 240,
                                child: Icon(Icons.restaurant_menu, size: 64, color: wellGreen),
                              ),
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
                                      await VoteService.instance.unlikePost(_post.id);
                                      if (mounted) setState(() => _liked = false);
                                    } else {
                                      await VoteService.instance.likePost(_post.id);
                                      if (mounted) setState(() => _liked = true);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                                icon: Icon(
                                  _liked ? Icons.favorite : Icons.favorite_border,
                                  color: nestOrange,
                                  size: 22,
                                ),
                                label: Text(
                                  _liked ? 'Liked' : 'Like',
                                  style: const TextStyle(color: nestOrange, fontWeight: FontWeight.w600),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: nestOrange,
                                ),
                              ),
                            const Spacer(),
                            if (_post.recipeId != null)
                              Material(
                                color: const Color(0x1A097333),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      fullscreenDialog: true,
                                      builder: (context) => RecipeDetailScreen(recipeId: _post.recipeId!),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Text(
                                      'View Recipe',
                                      style: TextStyle(
                                        color: wellGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
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
                const SliverToBoxAdapter(
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFEAE6DF)),
                ),
                // Comments header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: Text(
                      'Comments (${_comments.length})',
                      style: TextStyle(
                        fontFamily: 'HelveticaNow',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[600],
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
                        child: CircularProgressIndicator(color: wellGreen),
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
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFFF9BD21).withOpacity(0.3),
                                    child: Text(
                                      _getInitials(c.userName),
                                      style: const TextStyle(
                                        color: wellGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              Divider(height: 1, thickness: 0.5, color: Colors.grey[300]),
                          ],
                        );
                      },
                      childCount: _comments.length,
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
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                          filled: true,
                          fillColor: const Color(0xFFF0F0F0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: wellGreen,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _addComment,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
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
