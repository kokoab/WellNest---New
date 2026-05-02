import 'package:flutter/material.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/screens/post_detail_screen.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/widgets/initials_avatar.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/services/user_service.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  PublicUserProfile? _profile;
  CurrentUser? _currentUser;
  List<Recipe> _recipes = [];
  List<Post> _posts = [];
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        UserService.instance.fetchPublicProfile(widget.userId),
        if (AuthService.instance.isLoggedIn)
          UserService.instance.fetchCurrentUser()
        else
          Future.value(null),
        RecipeService.instance.fetchRecipes(userId: widget.userId),
        ApiService().fetchPosts(userId: widget.userId),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = results[0] as PublicUserProfile;
        _currentUser = results.length > 1 ? results[1] as CurrentUser? : null;
        _recipes = (results[2] as RecipeListResponse).recipes;
        _posts = results[3] as List<Post>;
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
                color: nestOrange.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: nestOrange.withOpacity(0.4)),
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
              _buildStat('${_recipes.length}', 'Recipes'),
              const SizedBox(width: 24),
              _buildStat('${_posts.length}', 'Posts'),
              const SizedBox(width: 24),
              _buildStat('${profile.followersCount}', 'Followers'),
              const SizedBox(width: 24),
              _buildStat('${profile.followingCount}', 'Following'),
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
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recipes.length,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    right: index < _recipes.length - 1 ? 15 : 0,
                  ),
                  child: _buildRecipeMiniCard(_recipes[index]),
                ),
              ),
            ),
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
        ],
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

  Widget _buildStat(String value, String label) {
    return Column(
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
  }

  Widget _buildRecipeMiniCard(Recipe recipe) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
        ),
      ),
      child: Container(
        width: 160,
        height: 180,
        decoration: BoxDecoration(
          color: wellGreen,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child:
                    recipe.displayImageUrl != null &&
                        recipe.displayImageUrl!.isNotEmpty
                    ? Image.network(
                        recipe.displayImageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        width: double.infinity,
                        cacheWidth: 600,
                        errorBuilder: (_, __, ___) => _placeholderImage(),
                      )
                    : _placeholderImage(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recipe.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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

  Widget _placeholderImage() {
    return Container(
      color: Colors.white24,
      child: const Icon(Icons.restaurant, color: Colors.white70, size: 48),
    );
  }
}
