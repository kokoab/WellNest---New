import 'package:flutter/material.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/screens/recipe_form_screen.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/report_service.dart';
import 'package:my_app/services/vote_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);
  static const Color accentYellow = Color(0xFFFDB813);

  Recipe? _recipe;
  bool _loading = true;
  String? _error;
  bool _liked = false;

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
      final recipe = await RecipeService.instance.fetchRecipe(widget.recipeId);
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
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

  Future<void> _reportRecipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report recipe?'),
        content: const Text('Report this recipe to moderators?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ReportService.instance.reportRecipe(_recipe!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted'), backgroundColor: wellGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: nestOrange),
        );
      }
    }
  }

  Future<void> _deleteRecipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await RecipeService.instance.deleteRecipe(widget.recipeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe deleted'), backgroundColor: wellGreen),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: nestOrange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Recipe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: wellGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_recipe != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) async {
                if (v == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeFormScreen(recipe: _recipe),
                    ),
                  ).then((_) => _load());
                } else if (v == 'delete') {
                  _deleteRecipe();
                } else if (v == 'report' && AuthService.instance.isLoggedIn) {
                  await _reportRecipe();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (AuthService.instance.isLoggedIn)
                  const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: wellGreen))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: nestOrange),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          style: FilledButton.styleFrom(backgroundColor: wellGreen),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRecipeImage(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _recipe!.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1a1a1a),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildMetaRow(),
                            if (AuthService.instance.isLoggedIn) ...[
                              const SizedBox(height: 10),
                              _buildLikeButton(),
                            ],
                            if (_recipe!.user != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'By ${_recipe!.userDisplayName}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
                            _buildSectionTitle('Ingredients'),
                            const SizedBox(height: 12),
                            _buildIngredientsList(),
                            const SizedBox(height: 28),
                            _buildSectionTitle('Instructions'),
                            const SizedBox(height: 12),
                            _buildInstructions(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRecipeImage() {
    const double imageHeight = 240;
    if (_recipe!.displayImageUrl != null && _recipe!.displayImageUrl!.isNotEmpty) {
      return Container(
        height: imageHeight,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: Image.network(
          _recipe!.displayImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(imageHeight),
        ),
      );
    }
    return _buildImagePlaceholder(imageHeight);
  }

  Widget _buildImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [wellGreen.withOpacity(0.85), wellGreen.withOpacity(0.6)],
        ),
      ),
      child: Icon(Icons.restaurant_rounded, size: 80, color: Colors.white.withOpacity(0.9)),
    );
  }

  Widget _buildLikeButton() {
    return Row(
      children: [
        IconButton(
          onPressed: () async {
            if (!AuthService.instance.isLoggedIn) return;
            try {
              if (_liked) {
                await VoteService.instance.unlikeRecipe(_recipe!.id);
                if (mounted) setState(() => _liked = false);
              } else {
                await VoteService.instance.likeRecipe(_recipe!.id);
                if (mounted) setState(() => _liked = true);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                );
              }
            }
          },
          icon: Icon(
            _liked ? Icons.favorite : Icons.favorite_border,
            color: _liked ? Colors.pink : nestOrange,
            size: 28,
          ),
        ),
        Text(
          _liked ? 'Liked' : 'Like',
          style: TextStyle(fontSize: 14, color: nestOrange, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMetaRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _MetaChip(
          icon: Icons.schedule_rounded,
          label: '${_recipe!.prepTime} min',
        ),
        if (_recipe!.category != null)
          _MetaChip(
            icon: Icons.category_rounded,
            label: _recipe!.category!.name,
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: wellGreen,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildIngredientsList() {
    final ingredients = _recipe!.ingredients;
    if (ingredients == null || ingredients.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          'No ingredients listed.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: ingredients.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final ing = ingredients[index];
          final qty = ing.quantity.toInt() == ing.quantity
              ? ing.quantity.toInt().toString()
              : ing.quantity.toString();
          final amount = ing.unit.isEmpty ? qty : '$qty ${ing.unit}';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: wellGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                      children: [
                        if (amount.isNotEmpty)
                          TextSpan(
                            text: '$amount ',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: wellGreen),
                          ),
                        TextSpan(text: ing.name),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        _recipe!.instructions,
        style: TextStyle(
          fontSize: 16,
          height: 1.65,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  static const Color wellGreen = Color(0xFF097333);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: wellGreen.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: wellGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: wellGreen,
            ),
          ),
        ],
      ),
    );
  }
}
