import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/post_service.dart';
import 'package:my_app/services/report_service.dart';
import 'package:my_app/services/vote_service.dart';
import 'package:my_app/widgets/initials_avatar.dart';
import 'package:image_picker/image_picker.dart';

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
  final TextEditingController _commentController = TextEditingController();
  XFile? _selectedImage;

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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    try {
      final comment = await PostService.instance.addComment(_post.id, text, image: _selectedImage);
      if (comment != null && mounted) {
        _commentController.clear();
        setState(() => _selectedImage = null);
        setState(() => _comments = [..._comments, comment]);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added')),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Post',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 26),
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
                            InitialsAvatar(
                              name: _post.userName,
                              size: 48,
                              imageUrl: _post.displayAuthorProfilePhotoUrl,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _post.userName,
                                    style: textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatPostTime(_post.createdAt),
                                    style: TextStyle(
                                      fontFamily: 'HelveticaNow',
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (AuthService.instance.isLoggedIn)
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
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
                            style: textTheme.bodyLarge?.copyWith(
                              fontFamily: 'HelveticaNow',
                              fontSize: 18,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (_post.displayImageUrl != null && _post.displayImageUrl!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _post.displayImageUrl!,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.imagePlaceholderGreen,
                                height: 240,
                                child: Icon(
                                  Icons.restaurant_menu,
                                  size: 64,
                                  color: colorScheme.primary,
                                ),
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
                                  color: colorScheme.secondary,
                                  size: 22,
                                ),
                                label: Text(
                                  _liked ? 'Liked' : 'Like',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: colorScheme.secondary,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: colorScheme.secondary,
                                ),
                              ),
                            const Spacer(),
                            if (_post.recipeId != null)
                              Material(
                                color: colorScheme.primary.withValues(alpha: 0.16),
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
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Text(
                                      'View Recipe',
                                      style: textTheme.labelLarge?.copyWith(
                                        color: colorScheme.primary,
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
                  child: Divider(height: 1, thickness: 1, color: theme.dividerColor),
                ),
                // Comments header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: Text(
                      'Comments (${_comments.length})',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
                        child: CircularProgressIndicator(),
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
                                  InitialsAvatar(
                                    name: c.userName,
                                    size: 32,
                                    imageUrl: c.displayProfilePhotoUrl,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.userName,
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontFamily: 'HelveticaNow',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          c.comment,
                                          style: textTheme.bodyMedium?.copyWith(
                                            fontFamily: 'HelveticaNow',
                                            fontSize: 14,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (c.imageUrl != null && c.imageUrl!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              c.imageUrl!,
                                              height: 120,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: colorScheme.surfaceContainerHighest,
                                                height: 120,
                                                child: Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (index < _comments.length - 1)
                              Divider(height: 1, thickness: 0.5, color: theme.dividerColor),
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
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.24 : 0.06,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_selectedImage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        height: 80,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_selectedImage!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            style: textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: textTheme.bodyMedium?.copyWith(fontSize: 15),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: colorScheme.surfaceContainerHighest,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _pickImage,
                            customBorder: const CircleBorder(),
                            child: Semantics(
                              button: true,
                              label: _selectedImage != null
                                  ? 'Change selected image'
                                  : 'Add comment image',
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  _selectedImage != null
                                      ? Icons.image
                                      : Icons.image_outlined,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: colorScheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _addComment,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Semantics(
                                button: true,
                                label: 'Send comment',
                                child: Icon(
                                  Icons.send_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 22,
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
        ],
      ),
    );
  }
}
