import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wellnest/models/post.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/providers/theme_provider.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/widgets/wellnest_header.dart';
import 'package:wellnest/widgets/edit_profile_overlay.dart';
import 'package:wellnest/screens/recipe_detail_screen.dart';
import 'package:wellnest/screens/post_detail_screen.dart';
import 'package:wellnest/services/api_service.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/content_update_notifier.dart';
import 'package:wellnest/services/recipe_service.dart';
import 'package:wellnest/services/user_service.dart';
import 'package:wellnest/screens/follow_list_screen.dart';
import 'package:wellnest/screens/profile_activity_screen.dart';
import 'package:wellnest/widgets/profile_activity_helpers.dart';
import 'package:wellnest/widgets/profile_landscape_preview_card.dart';

enum _ActivityTab { recipes, posts, liked }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  /// Liked-tab icon accent (distinct from primary green / accent orange).
  static const Color kLikedHeartRed = Color(0xFFE53935);

  static const double _horizontalPadding = 20;
  static const double _bottomScrollPadding = 96;
  static const int _activityPreviewLimit = 5;

  CurrentUser? _user;
  List<Recipe> _myRecipes = [];
  int _myRecipesTotal = 0;
  List<Post> _myPosts = [];
  int _myPostsTotal = 0;
  /// Heart-liked recipes (not bookmarks).
  List<Recipe> _likedHeartRecipes = [];
  /// Heart-liked posts.
  List<Post> _likedHeartPosts = [];

  bool _loading = true;
  bool _uploadingPhoto = false;
  bool _loggingOut = false;
  bool _deactivatingAccount = false;
  String? _error;

  _ActivityTab _activityTab = _ActivityTab.recipes;

  @override
  void initState() {
    super.initState();
    ContentUpdateNotifier.instance.addListener(_onContentUpdate);
    _load();
  }

  @override
  void dispose() {
    ContentUpdateNotifier.instance.removeListener(_onContentUpdate);
    super.dispose();
  }

  void _onContentUpdate() {
    final update = ContentUpdateNotifier.instance.lastUpdate;
    if (!mounted || update == null) return;
    if (update.action != ContentUpdateAction.likeChanged) return;

    if (update.isActive) {
      _load();
      return;
    }

    setState(() {
      switch (update.kind) {
        case ContentUpdateKind.recipe:
          _likedHeartRecipes.removeWhere((recipe) => recipe.id == update.id);
          break;
        case ContentUpdateKind.post:
          _likedHeartPosts.removeWhere((post) => post.id == update.id);
          break;
      }
    });
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

      if (AuthService.instance.isLoggedIn && user == null) {
        setState(() {
          _user = null;
          _myRecipes = [];
          _myRecipesTotal = 0;
          _myPosts = [];
          _myPostsTotal = 0;
          _likedHeartRecipes = [];
          _likedHeartPosts = [];
          _loading = false;
          _error =
              'Could not load your profile from the server. Pull to refresh, or run backend migrations (php artisan migrate) if you recently updated the API.';
        });
        return;
      }

      RecipeListResponse? recipesResponse;
      PostListResponse? postsResponse;
      RecipeListResponse? likedRecipesHeartResponse;
      PostListResponse? likedPostsHeartResponse;

      if (user != null) {
        final futures = <Future<dynamic>>[
          RecipeService.instance.fetchRecipes(userId: user.id, page: 1),
          ApiService().fetchPostsPaginated(
            userId: user.id,
            page: 1,
            perPage: 10,
          ),
        ];
        if (AuthService.instance.isLoggedIn) {
          futures.add(RecipeService.instance.fetchRecipes(liked: true, page: 1));
          futures.add(
            ApiService().fetchPostsPaginated(liked: true, page: 1, perPage: 10),
          );
        }
        final results = await Future.wait(futures);
        recipesResponse = results[0] as RecipeListResponse;
        postsResponse = results[1] as PostListResponse;
        if (AuthService.instance.isLoggedIn && results.length > 3) {
          likedRecipesHeartResponse = results[2] as RecipeListResponse;
          likedPostsHeartResponse = results[3] as PostListResponse;
        }
      }

      if (!mounted) return;
      setState(() {
        _user = user;
        _myRecipes = recipesResponse?.recipes ?? [];
        _myRecipesTotal = recipesResponse?.total ?? 0;
        _myPosts = postsResponse?.posts ?? [];
        _myPostsTotal = postsResponse?.total ?? 0;
        _likedHeartRecipes = likedRecipesHeartResponse?.recipes ?? [];
        _likedHeartPosts = likedPostsHeartResponse?.posts ?? [];
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
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceMuted = colorScheme.brightness == Brightness.dark
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
        : const Color(0xFFF0EDE8);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: kPrimaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            _horizontalPadding,
            AppSpacing.sm,
            _horizontalPadding,
            _bottomScrollPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              const WellnestHeader(),
              const SizedBox(height: AppSpacing.lg),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: kPrimaryGreen),
                  ),
                )
              else ...[
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: kAccentOrange.withValues(alpha: 0.1),
                        border: Border.all(color: kAccentOrange),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: kAccentOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: kAccentOrange,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Profile header — centered
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildProfileAvatar(),
                    const SizedBox(height: 16),
                    Text(
                      _user?.displayName ?? 'Guest',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_user != null)
                      Text(
                        _user!.email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),

                if ((_user?.accountStatus ?? 'active') != 'active') ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: kAccentOrange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kAccentOrange.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      'Your account is ${_statusLabel(_user!.accountStatus)}.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kAccentOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),
                _buildStatsRow(),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your activity',
                        style: georgiaProDisplayStyle(
                          fontSize: 18,
                          color: kPrimaryGreen,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (_) => ProfileActivityScreen(
                              initialTabIndex: _activityTabIndex(),
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: kPrimaryGreen,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm2),
                _buildActivityTabBar(),
                const SizedBox(height: AppSpacing.md),
                _buildActivityContent(),
                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Settings',
                  style: georgiaProDisplayStyle(
                    fontSize: 18,
                    color: kPrimaryGreen,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm2),
                _buildSettingsCard(surfaceMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openFollowList(FollowTab tab) {
    final id = _user?.id;
    if (id == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => FollowListScreen(
          userId: id,
          displayName: _user?.displayName,
          initialTab: tab,
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildStatCell('$_myRecipesTotal', 'Recipes'),
        ),
        Expanded(
          child: _buildStatCell('$_myPostsTotal', 'Posts'),
        ),
        Expanded(
          child: _buildStatCell(
            '${_user?.followersCount ?? 0}',
            'Followers',
            onTap: () => _openFollowList(FollowTab.followers),
          ),
        ),
        Expanded(
          child: _buildStatCell(
            '${_user?.followingCount ?? 0}',
            'Following',
            onTap: () => _openFollowList(FollowTab.following),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCell(String value, String label, {VoidCallback? onTap}) {
    final column = Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kPrimaryGreen,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (onTap == null) return column;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: column,
        ),
      ),
    );
  }

  Color _activitySelectedSurface(_ActivityTab tab) {
    switch (tab) {
      case _ActivityTab.recipes:
        return kAccentOrange.withValues(alpha: 0.12);
      case _ActivityTab.posts:
        return kPrimaryGreen.withValues(alpha: 0.12);
      case _ActivityTab.liked:
        return kLikedHeartRed.withValues(alpha: 0.10);
    }
  }

  Color _activityIconColor(_ActivityTab tab, bool selected) {
    if (!selected) return kCaptionGray;
    switch (tab) {
      case _ActivityTab.recipes:
        return kAccentOrange;
      case _ActivityTab.posts:
        return kPrimaryGreen;
      case _ActivityTab.liked:
        return kLikedHeartRed;
    }
  }

  Widget _buildActivityTabBar() {
    return Row(
      children: [
        _buildActivityTabButton(
          icon: Icons.flatware_rounded,
          tooltip: 'My Recipes',
          tab: _ActivityTab.recipes,
        ),
        _buildActivityTabButton(
          icon: Icons.article_rounded,
          tooltip: 'My Posts',
          tab: _ActivityTab.posts,
        ),
        _buildActivityTabButton(
          icon: Icons.favorite_rounded,
          tooltip: 'Liked',
          tab: _ActivityTab.liked,
        ),
      ],
    );
  }

  Widget _buildActivityTabButton({
    required IconData icon,
    required String tooltip,
    required _ActivityTab tab,
  }) {
    final selected = _activityTab == tab;
    final outline = wellnestOutlineColor(context);
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _activityTab = tab),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected ? _activitySelectedSurface(tab) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: selected ? outline : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: _activityIconColor(tab, selected),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityContent() {
    switch (_activityTab) {
      case _ActivityTab.recipes:
        return _buildRecipesSection();
      case _ActivityTab.posts:
        return _buildPostsSection();
      case _ActivityTab.liked:
        return _buildLikedSection();
    }
  }

  int _activityTabIndex() {
    switch (_activityTab) {
      case _ActivityTab.recipes:
        return 0;
      case _ActivityTab.posts:
        return 1;
      case _ActivityTab.liked:
        return 2;
    }
  }

  Widget _buildRecipesSection() {
    if (_myRecipes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          AuthService.instance.isLoggedIn
              ? 'No recipes yet. Add one to get started!'
              : 'Sign in to see your recipes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final visibleRecipes = _myRecipes.take(_activityPreviewLimit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...visibleRecipes.map(
          (recipe) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm2),
            child: RepaintBoundary(
              child: _buildRecipePreviewCard(recipe),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsSection() {
    if (!AuthService.instance.isLoggedIn) {
      return _buildSignedOutPlaceholder('Sign in to see your posts.');
    }
    if (_myPosts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'No posts yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final visiblePosts = _myPosts.take(_activityPreviewLimit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...visiblePosts.map(
          (post) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm2),
            child: RepaintBoundary(
              child: _buildPostPreviewCard(post),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLikedSection() {
    if (!AuthService.instance.isLoggedIn) {
      return _buildSignedOutPlaceholder(
        'Sign in to see recipes and posts you\'ve liked.',
      );
    }
    final merged = mergeLikedActivityRows(
      _likedHeartRecipes,
      _likedHeartPosts,
    );
    if (merged.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'No likes yet. Tap the heart on a recipe or post.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final visible = merged.take(_activityPreviewLimit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...visible.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm2),
            child: RepaintBoundary(
              child: row.recipe != null
                  ? _buildRecipePreviewCard(row.recipe!)
                  : _buildPostPreviewCard(row.post!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignedOutPlaceholder(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(Color surfaceMuted) {
    final borderColor = wellnestOutlineColor(context);
    final themeProvider = context.watch<ThemeProvider>();

    Widget divider() => Divider(
          height: 1,
          thickness: 1,
          color: borderColor.withValues(alpha: 0.5),
        );

    return Container(
      decoration: BoxDecoration(
        color: surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          if (AuthService.instance.isLoggedIn && _user != null) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              leading: Icon(Icons.edit_outlined, color: kPrimaryGreen, size: 22),
              title: Text(
                'Edit Profile',
                style: TextStyle(
                  fontFamily: kFontAppFamily,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: kCaptionGray,
              ),
              onTap: () => showEditProfileOverlay(
                context,
                _user!,
                onSaved: _load,
              ),
            ),
            divider(),
          ],
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            leading: Icon(Icons.dark_mode_outlined, color: kPrimaryGreen, size: 22),
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
          ),
          if (AuthService.instance.isLoggedIn) ...[
            divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              leading: Icon(Icons.logout_rounded, color: kBodyTextDark),
              title: Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: kFontAppFamily,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: _loggingOut
                  ? null
                  : () async {
                      setState(() => _loggingOut = true);
                      try {
                        await AuthService.instance.logout();
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _loggingOut = false);
                      }
                    },
              trailing: _loggingOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kPrimaryGreen,
                      ),
                    )
                  : Icon(Icons.chevron_right_rounded, color: kCaptionGray),
            ),
            divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              leading: Icon(Icons.person_off_outlined, color: kAccentOrange),
              title: Text(
                _deactivatingAccount ? 'Deactivating…' : 'Deactivate Account',
                style: const TextStyle(
                  fontFamily: kFontAppFamily,
                  fontWeight: FontWeight.w600,
                  color: kAccentOrange,
                ),
              ),
              onTap: _deactivatingAccount ? null : _confirmDeactivateAccount,
              trailing: _deactivatingAccount
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kAccentOrange,
                      ),
                    )
                  : Icon(Icons.chevron_right_rounded, color: kAccentOrange),
            ),
          ],
        ],
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
      onTap: AuthService.instance.isLoggedIn && !_uploadingPhoto
          ? _pickAndUploadProfilePhoto
          : null,
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
                      errorBuilder: (context, error, stackTrace) =>
                          _initialsContent(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryGreen,
                            strokeWidth: 2,
                          ),
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
                  color: kPrimaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
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
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
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
      style: const TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: kPrimaryGreen,
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
          SnackBar(content: Text(errorMsg), backgroundColor: kAccentOrange),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _confirmDeactivateAccount() async {
    final reasonController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will hide your account until you sign in again. You can reactivate it later by logging in.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason (optional):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'e.g. Taking a break',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'confirmed': true,
              'reason': reasonController.text,
            }),
            style: FilledButton.styleFrom(backgroundColor: kAccentOrange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (result == null || result['confirmed'] != true || !mounted) return;

    setState(() {
      _deactivatingAccount = true;
    });

    try {
      await AuthService.instance.deactivateAccount(
        reason: result['reason'] as String?,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: kAccentOrange,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deactivatingAccount = false;
        });
      }
    }
  }

  Widget _buildRecipePreviewCard(Recipe recipe) {
    final creator = recipe.userDisplayName.trim().isEmpty
        ? (_user?.displayName ?? 'Creator')
        : recipe.userDisplayName;
    final when = formatProfilePostedAt(recipe.createdAt);
    return ProfileLandscapePreviewCard(
      title: recipe.title,
      creatorName: creator,
      postedLabel: when.isEmpty ? '—' : when,
      imageUrl: recipePreviewImageUrl(recipe),
      placeholderIcon: Icons.restaurant_rounded,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => RecipeDetailScreen(recipeId: recipe.id),
        ),
      ),
    );
  }

  Widget _buildPostPreviewCard(Post post) {
    final when = formatProfilePostedAt(post.createdAt);
    final img = post.displayImageUrl ??
        (post.galleryImages.isNotEmpty
            ? post.galleryImages.first.displayUrl
            : null);
    return ProfileLandscapePreviewCard(
      title: postPreviewTitle(post),
      creatorName:
          post.userName.trim().isEmpty ? 'Member' : post.userName.trim(),
      postedLabel: when.isEmpty ? '—' : when,
      imageUrl: img,
      placeholderIcon: Icons.article_rounded,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => PostDetailScreen(post: post),
        ),
      ),
    );
  }
}
