import 'package:flutter/material.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/widgets/notifications_dropdown.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.menu, color: nestOrange, size: 35),
                Image.asset('lib/assets/images/logo1.png', height: 50),
                NotificationsDropdown(
                  iconColor: nestOrange,
                  child: const Icon(Icons.notifications, color: nestOrange, size: 35),
                ),
              ],
            ),
            const SizedBox(height: 30),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: wellGreen)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: nestOrange)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      style: FilledButton.styleFrom(backgroundColor: wellGreen),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else ...[
              CircleAvatar(
                radius: 60,
                backgroundColor: wellGreen.withOpacity(0.2),
                child: Text(
                  _displayInitials(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: wellGreen),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _user?.displayName ?? 'Guest',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: wellGreen),
              ),
              if (_user != null)
                Text(
                  _user!.email,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatColumn('${_myRecipes.length}', 'Recipes'),
                  const SizedBox(width: 40),
                  _buildStatColumn('${_myPosts.length}', 'Posts'),
                ],
              ),
              const SizedBox(height: 30),

              if (AuthService.instance.isLoggedIn)
                OutlinedButton(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => const RecipeFormScreen()),
                    );
                    if (result == true && mounted) _load();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: wellGreen, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  child: const Text(
                    'Add new Recipe',
                    style: TextStyle(color: wellGreen, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              if (AuthService.instance.isLoggedIn) const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.instance.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                },
                icon: const Icon(Icons.logout, size: 20, color: nestOrange),
                label: const Text(
                  'Logout',
                  style: TextStyle(color: nestOrange, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: nestOrange, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
              ),
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
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < _myRecipes.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: i < _myRecipes.length - 1 ? 15 : 0),
                          child: _buildRecipeMiniCard(_myRecipes[i]),
                        ),
                    ],
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

  String _displayInitials() {
    if (_user == null) return '?';
    final first = _user!.firstName.isNotEmpty ? _user!.firstName[0] : '';
    final last = _user!.lastName.isNotEmpty ? _user!.lastName[0] : '';
    return '${first.toUpperCase()}${last.toUpperCase()}'.trim();
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
          style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
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
        MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipeId: recipe.id)),
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
                        width: double.infinity,
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
