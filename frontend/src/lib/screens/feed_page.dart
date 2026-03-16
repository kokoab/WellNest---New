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
  late Future<List<Post>> _postsFuture;
  final Map<int, bool> _postLiked = {};
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
    _loadPosts();
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (AuthService.instance.isLoggedIn) {
      final u = await UserService.instance.fetchCurrentUser();
      if (mounted) setState(() => _currentUser = u);
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _postsFuture = _apiService.fetchPosts());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF097333)));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final posts = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              await _loadPosts();
              await _loadUser();
            },
            color: wellGreen,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSpacing.gapV8,
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: WellnestHeader(),
                  ),
                  AppSpacing.gapV16,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.md),
                    child: const Text(
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
                  if (posts.isEmpty && !AuthService.instance.isLoggedIn)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No posts yet. Sign in to create one!')),
                    )
                  else if (posts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('No posts yet. Share something!')),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: posts.length,
                      itemBuilder: (context, index) => _buildFeedCard(posts[index]),
                    ),
                const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
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
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: const TextStyle(
                      color: wellGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
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
    final expanded = _commentsExpanded[post.id] ?? false;
    final comments = _postComments[post.id] ?? [];
    _commentControllers[post.id] ??= TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (context) => PostDetailScreen(post: post),
                  ),
                ),
                child: InitialsAvatar(name: post.userName, size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (context) => PostDetailScreen(post: post),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        formatPostTime(post.createdAt),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                  ),
                  child: const Text('View Recipe', style: TextStyle(color: wellGreen, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => PostDetailScreen(post: post),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.content),
                if (post.imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(
                      post.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.imagePlaceholderGreen,
                      height: 180,
                      child: Icon(Icons.restaurant_menu, size: 48, color: wellGreen),
                    ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (AuthService.instance.isLoggedIn) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post.id),
                  child: Row(
                    children: [
                      Icon(liked ? Icons.favorite : Icons.favorite_border, color: nestOrange, size: 22),
                      const SizedBox(width: 6),
                      Text(liked ? 'Liked' : 'Like', style: const TextStyle(color: nestOrange, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _toggleComments(post.id),
                  child: Row(
                    children: [
                      const Icon(Icons.comment, color: wellGreen, size: 22),
                      const SizedBox(width: 6),
                      Text('Comment (${comments.length})', style: const TextStyle(color: wellGreen, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black54),
                  onSelected: (v) => v == 'report' ? _reportPost(post.id) : null,
                  itemBuilder: (context) => [const PopupMenuItem(value: 'report', child: Text('Report'))],
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 12),
              ...comments.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black87, fontSize: 14),
                              children: [
                                TextSpan(text: '${c.userName}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: c.comment),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentControllers[post.id],
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.7),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _addComment(post.id),
                    icon: const Icon(Icons.send, color: wellGreen),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _toggleLike(int postId) async {
    try {
      final liked = _postLiked[postId] ?? false;
      if (liked) {
        await VoteService.instance.unlikePost(postId);
        if (mounted) setState(() => _postLiked[postId] = false);
      } else {
        await VoteService.instance.likePost(postId);
        if (mounted) setState(() => _postLiked[postId] = true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleComments(int postId) async {
    final expanded = _commentsExpanded[postId] ?? false;
    if (!expanded) {
      final comments = await PostService.instance.fetchComments(postId);
      if (mounted) setState(() {
        _commentsExpanded[postId] = true;
        _postComments[postId] = comments;
      });
    } else {
      if (mounted) setState(() => _commentsExpanded[postId] = false);
    }
  }

  Future<void> _addComment(int postId) async {
    final ctrl = _commentControllers[postId];
    if (ctrl == null || ctrl.text.trim().isEmpty) return;
    try {
      final comment = await PostService.instance.addComment(postId, ctrl.text);
      if (comment != null && mounted) {
        ctrl.clear();
        setState(() {
          _postComments[postId] = [...(_postComments[postId] ?? []), comment];
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) setState(() => _selectedImage = x);
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    if (_posting) return;
    setState(() => _posting = true);
    try {
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
                    child: Image.network(r.displayImageUrl!, width: 48, height: 48, fit: BoxFit.cover),
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