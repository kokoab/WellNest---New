import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/providers/theme_provider.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/widgets/wellnest_header.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/screens/recipe_form_screen.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/services/user_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  CurrentUser? _user;
  List<Recipe> _myRecipes = [];
  List<Post> _myPosts = [];
  bool _loading = true;
  bool _uploadingPhoto = false;
  bool _addingRecipe = false;
  bool _loggingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

      List<Recipe> recipes = [];
      List<Post> posts = [];
      if (user != null) {
        final results = await Future.wait([
          RecipeService.instance.fetchRecipes(userId: user.id),
          ApiService().fetchPosts(userId: user.id),
        ]);
        recipes = (results[0] as RecipeListResponse).recipes;
        posts = results[1] as List<Post>;
      }

      if (!mounted) return;
      setState(() {
        _user = user;
        _myRecipes = recipes;
        _myPosts = posts;
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: wellGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const WellnestHeader(),
            const SizedBox(height: 30),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: wellGreen)),
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: nestOrange.withOpacity(0.1),
                      border: Border.all(color: nestOrange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: nestOrange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: nestOrange, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              _buildProfileAvatar(),
              const SizedBox(height: 10),
              Text(
                _user?.displayName ?? 'Guest',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: wellGreen),
              ),
              if (_user != null)
                Text(
                  _user!.email,
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 20),

              // Theme toggle
              _buildThemeToggle(context),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatColumn('${_myRecipes.length}', 'Recipes'),
                  const SizedBox(width: 40),
                  _buildStatColumn('${_myPosts.length}', 'Posts'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatColumn('${_user?.followersCount ?? 0}', 'Followers'),
                  const SizedBox(width: 40),
                  _buildStatColumn('${_user?.followingCount ?? 0}', 'Following'),
                ],
              ),
              const SizedBox(height: 30),

              if (AuthService.instance.isLoggedIn) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: ValueKey('add_recipe_${Theme.of(context).brightness}'),
                    onPressed: _addingRecipe ? null : () async {
                      setState(() => _addingRecipe = true);
                      try {
                        final result = await RecipeFormScreen.showAsModal(context);
                        if (result == true && mounted) _load();
                      } finally {
                        if (mounted) setState(() => _addingRecipe = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _addingRecipe
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Add new Recipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/conversations'),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Messages'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: wellGreen,
                      side: const BorderSide(color: wellGreen),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'My Recipes',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: wellGreen),
                ),
              ),
              const SizedBox(height: 20),

              if (_myRecipes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    AuthService.instance.isLoggedIn
                        ? 'No recipes yet. Add one to get started!'
                        : 'Sign in to see your recipes.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _myRecipes.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(right: index < _myRecipes.length - 1 ? 15 : 0),
                      child: RepaintBoundary(child: _buildRecipeMiniCard(_myRecipes[index])),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              if (AuthService.instance.isLoggedIn)
                TextButton.icon(
                  key: ValueKey('logout_${Theme.of(context).brightness}'),
                  onPressed: _loggingOut ? null : () async {
                    setState(() => _loggingOut = true);
                    try {
                      await AuthService.instance.logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }
                    } finally {
                      if (mounted) setState(() => _loggingOut = false);
                    }
                  },
                  icon: _loggingOut
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: nestOrange, strokeWidth: 2))
                      : Icon(Icons.logout, size: 18, color: nestOrange),
                  label: Text(
                    'Logout',
                    style: TextStyle(
                      fontFamily: kFontAppFamily,
                      fontWeight: FontWeight.bold,
                      color: nestOrange,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 100),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return ListTile(
      key: ValueKey('theme_${themeProvider.isDarkMode}'),
      leading: Icon(Icons.dark_mode_outlined, color: wellGreen, size: 24),
      title: Text(
        'Dark Mode',
        style: TextStyle(
          fontFamily: kFontAppFamily,
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Switch(
        value: themeProvider.isDarkMode,
        onChanged: (_) => themeProvider.toggleTheme(),
      ),
    );
  }

  String _displayInitials() {
    if (_user == null) return '?';
    final first = _user!.firstName.isNotEmpty ? _user!.firstName[0] : '';
    final last = _user!.lastName.isNotEmpty ? _user!.lastName[0] : '';
    return '${first.toUpperCase()}${last.toUpperCase()}'.trim();
  }

  Widget _buildProfileAvatar() {
    final photoUrl = _user?.displayProfilePhotoUrl;
    return GestureDetector(
      onTap: AuthService.instance.isLoggedIn && !_uploadingPhoto ? _pickAndUploadProfilePhoto : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: const Color(0xFFFFEECC),
            child: photoUrl != null && photoUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      photoUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      cacheWidth: 240,
                      errorBuilder: (_, __, ___) => _initialsContent(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: wellGreen, strokeWidth: 2),
                        );
                      },
                    ),
                  )
                : _initialsContent(),
          ),
          if (AuthService.instance.isLoggedIn && !_uploadingPhoto)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: wellGreen,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          if (_uploadingPhoto)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialsContent() {
    return Text(
      _displayInitials(),
      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: wellGreen),
    );
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;
    setState(() {
      _uploadingPhoto = true;
    });
    try {
      await UserService.instance.uploadProfilePhoto(image);
      if (!mounted) return;
      // Only refresh the user data, not the entire page
      final user = await UserService.instance.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
      });
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: nestOrange),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: wellGreen),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRecipeMiniCard(Recipe recipe) {
    final colors = [wellGreen, accentYellow];
    final bgColor = colors[recipe.id % 2];
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(fullscreenDialog: true, builder: (context) => RecipeDetailScreen(recipeId: recipe.id)),
      ),
      child: Container(
        width: 160,
        height: 180,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: recipe.displayImageUrl != null && recipe.displayImageUrl!.isNotEmpty
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

  Widget _placeholderImage() {
    return Container(
      color: Colors.white24,
      child: const Icon(Icons.restaurant, color: Colors.white70, size: 48),
    );
  }
}
