import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wellnest/app_route_observer.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/screens/custom_bottom_nav.dart';
import 'package:wellnest/screens/profile_page.dart';
import 'package:wellnest/screens/recipe_form_screen.dart';
import 'package:wellnest/screens/saved_recipes_screen.dart';
import 'package:wellnest/screens/conversation_chat_screen.dart';
import 'package:wellnest/screens/create_post_screen.dart';
import 'package:wellnest/services/conversation_service.dart';
import 'feed_page.dart';
import 'user_dashboard/recipe_grid_view.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> with RouteAware {
  static const Color wellGreen = Color(0xFF097333);

  int _currentIndex = 0;
  int _feedRefreshKey = 0;
  int _savedRefreshKey = 0;
  final GlobalKey<RecipeGridViewState> _recipeGridViewKey =
      GlobalKey<RecipeGridViewState>();
  final List<bool> _tabHasBeenBuilt = [false, false, false, false];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// When a detail (or other) route pops, the tab under it still holds stale list state.
  @override
  void didPopNext() {
    if (!mounted) return;
    switch (_currentIndex) {
      case 0:
        _recipeGridViewKey.currentState?.refreshAfterRoutePop();
        break;
      case 1:
        setState(() => _feedRefreshKey++);
        break;
      case 2:
        setState(() => _savedRefreshKey++);
        break;
      case 3:
        // Profile listens to ContentUpdateNotifier and updates in place, so keep
        // its selected activity tab intact when returning from detail screens.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    _tabHasBeenBuilt[_currentIndex] = true;
    final pages = [
      _tabHasBeenBuilt[0]
          ? RecipeGridView(key: _recipeGridViewKey)
          : const SizedBox.shrink(),
      _tabHasBeenBuilt[1]
          ? FeedPage(key: ValueKey('feed_$_feedRefreshKey'))
          : const SizedBox.shrink(),
      _tabHasBeenBuilt[2]
          ? SavedRecipesScreen(key: ValueKey('saved_$_savedRefreshKey'))
          : const SizedBox.shrink(),
      _tabHasBeenBuilt[3] ? const ProfilePage() : const SizedBox.shrink(),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      floatingActionButton: CustomBottomNav.fab(
        onPressed: _showQuickActionsSheet,
      ),
      floatingActionButtonLocation: CustomBottomNav.fabLocation,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: IndexedStack(index: _currentIndex, children: pages),
      ),
      bottomNavigationBar: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: RepaintBoundary(
          child: CustomBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == _currentIndex && index == 0) {
                _recipeGridViewKey.currentState?.scrollToTop();
                return;
              }
              setState(() {
                _currentIndex = index;
                if (index == 1) _feedRefreshKey++;
                if (index == 2) _savedRefreshKey++;
              });
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickActionsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Container(
            decoration: BoxDecoration(
              color: wellnestCardSurface(sheetContext),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: wellnestOutlineColor(sheetContext),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuickActionTile(
                  icon: Icons.post_add_rounded,
                  label: 'Create new post',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!mounted) return;
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const CreatePostScreen(),
                      ),
                    );
                    if (created == true && mounted) {
                      setState(() {
                        _currentIndex = 1;
                        _feedRefreshKey++;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post created!'),
                          backgroundColor: wellGreen,
                        ),
                      );
                    }
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.7,
                  color: Theme.of(sheetContext).dividerColor,
                  indent: 16,
                  endIndent: 16,
                ),
                _QuickActionTile(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Create new recipe',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!mounted) return;
                    final result = await RecipeFormScreen.showAsModal(context);
                    if (result == true && mounted) {
                      setState(() => _currentIndex = 0);
                      await _recipeGridViewKey.currentState?.reload();
                    }
                  },
                ),
                Divider(
                  height: 1,
                  thickness: 0.7,
                  color: Theme.of(sheetContext).dividerColor,
                  indent: 16,
                  endIndent: 16,
                ),
                _QuickActionTile(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Chat with WellNest AI',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!mounted) return;
                    final svc = ConversationService();
                    try {
                      final conv = await svc.ensureAssistantConversation();
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => ConversationChatScreen(
                            conversationId: conv.id,
                            otherUserName: conv.otherUser.name,
                            otherUserProfilePhotoUrl:
                                conv.otherUser.displayProfilePhotoUrl,
                            isAssistant: true,
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm2,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
