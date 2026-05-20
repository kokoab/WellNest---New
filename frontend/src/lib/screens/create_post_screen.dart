import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/services/api_service.dart';
import 'package:wellnest/services/saved_recipe_service.dart';
import 'package:wellnest/services/user_service.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/widgets/initials_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const int _kMaxPostImages = 10;

  final ApiService _apiService = ApiService();
  final TextEditingController _controller = TextEditingController();
  CurrentUser? _currentUser;
  Recipe? _selectedRecipe;
  final List<XFile> _pickedImages = [];
  bool _loadingUser = true;
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await UserService.instance.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _loadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUser = false);
    }
  }

  Future<void> _pickImages() async {
    final remain = _kMaxPostImages - _pickedImages.length;
    if (remain <= 0) return;
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (!mounted) return;
    setState(() {
      _pickedImages.addAll(images.take(remain));
    });
  }

  Future<void> _pickRecipeFromSaved() async {
    try {
      final data = await SavedRecipeService.instance.fetchSavedRecipes(page: 1);
      if (!mounted) return;
      if (data.recipes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved recipes found to attach.')),
        );
        return;
      }

      final picked = await showModalBottomSheet<Recipe>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: data.recipes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final recipe = data.recipes[index];
              return ListTile(
                leading: const Icon(Icons.restaurant_menu_rounded),
                title: Text(
                  recipe.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${recipe.prepTime} min'),
                onTap: () => Navigator.pop(context, recipe),
              );
            },
          ),
        ),
      );

      if (picked != null && mounted) {
        setState(() => _selectedRecipe = picked);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _posting) return;

    setState(() => _posting = true);
    try {
      final post = await _apiService.createPost(
        content: content,
        recipeId: _selectedRecipe?.id,
      );
      final ids = <int>[];
      for (final file in _pickedImages) {
        ids.add(await _apiService.uploadPostImage(post.id, file));
      }
      if (ids.length > 1) {
        await _apiService.reorderPostImages(post.id, ids);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.accentOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Post',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadingUser)
                const LinearProgressIndicator(minHeight: 1.5)
              else
                Row(
                  children: [
                    InitialsAvatar(
                      name: _currentUser?.displayName ?? 'Guest',
                      size: 44,
                      imageUrl: _currentUser?.displayProfilePhotoUrl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentUser?.displayName ?? 'Guest',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                maxLines: 8,
                autofocus: true,
                enabled: !_posting,
                style: TextStyle(color: cs.onSurface),
                cursorColor: cs.primary,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: wellnestOutlineColor(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: wellnestOutlineColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: (_posting || _pickedImages.length >= _kMaxPostImages)
                        ? null
                        : _pickImages,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add photos'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _posting ? null : _pickRecipeFromSaved,
                    icon: const Icon(Icons.restaurant_menu_rounded),
                    label: const Text('Attach recipe'),
                  ),
                ],
              ),
              if (_pickedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _pickedImages.removeAt(oldIndex);
                      _pickedImages.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (var i = 0; i < _pickedImages.length; i++)
                      ReorderableDelayedDragStartListener(
                        key: ValueKey(_pickedImages[i].path + '_$i'),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  File(_pickedImages[i].path),
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 140,
                                    color: cs.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.image_rounded,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: _posting
                                    ? null
                                    : () => setState(
                                          () => _pickedImages.removeAt(i),
                                        ),
                              ),
                              if (i == 0)
                                Positioned(
                                  left: 10,
                                  bottom: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Cover',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
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
              ],
              if (_selectedRecipe != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedRecipe!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _posting
                            ? null
                            : () => setState(() => _selectedRecipe = null),
                        icon: Icon(Icons.close_rounded, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _posting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                child: _posting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text('Post'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
