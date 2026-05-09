import 'package:flutter/material.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/models/recipe_rating.dart';
import 'package:my_app/services/auth_service.dart';
import 'package:my_app/services/rating_service.dart';
import 'package:my_app/utils/media_url.dart';

/// Full-screen step-by-step cooking flow; prompts for a review when finished.
class RecipeCookModeScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeCookModeScreen({super.key, required this.recipe});

  @override
  State<RecipeCookModeScreen> createState() => _RecipeCookModeScreenState();
}

class _CookPage {
  _CookPage({
    required this.title,
    required this.instructions,
    this.imageUrl,
    this.prepMinutes,
  });

  final String title;
  final String instructions;
  final String? imageUrl;
  final int? prepMinutes;
}

class _RecipeCookModeScreenState extends State<RecipeCookModeScreen> {
  late final PageController _pageController;
  late final List<_CookPage> _pages;
  int _index = 0;
  RecipeRating? _userRating;
  bool _loadingRating = true;

  static const Color _wellGreen = Color(0xFF097333);

  @override
  void initState() {
    super.initState();
    _pages = _buildCookPages(widget.recipe);
    _pageController = PageController();
    _loadUserRating();
  }

  Future<void> _loadUserRating() async {
    if (!AuthService.instance.isLoggedIn) {
      if (mounted) setState(() => _loadingRating = false);
      return;
    }
    try {
      final r = await RatingService.instance.fetchUserRating(widget.recipe.id);
      if (mounted) setState(() {
        _userRating = r;
        _loadingRating = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingRating = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_CookPage> _buildCookPages(Recipe r) {
    if (r.hasStructuredSteps) {
      return r.steps!.asMap().entries.map((e) {
        final i = e.key + 1;
        final s = e.value;
        final img = s.image?.displayUrl ?? s.image?.url;
        return _CookPage(
          title: s.displayTitle(i),
          instructions: s.instructions?.trim() ?? '',
          imageUrl: img != null && img.isNotEmpty ? resolveStorageDisplayUrl(img) ?? img : null,
          prepMinutes: s.prepTimeMinutes,
        );
      }).toList();
    }

    final raw = r.instructions.trim();
    if (raw.isEmpty) {
      return [
        _CookPage(
          title: 'Cook',
          instructions: 'No instructions were provided for this recipe.',
          imageUrl: null,
          prepMinutes: null,
        ),
      ];
    }

    final lines = raw.split(RegExp(r'\r?\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.length <= 1) {
      return [
        _CookPage(
          title: 'Cook',
          instructions: raw,
          imageUrl: null,
          prepMinutes: r.prepTime > 0 ? r.prepTime : null,
        ),
      ];
    }

    return lines.asMap().entries.map((e) {
      return _CookPage(
        title: 'Step ${e.key + 1}',
        instructions: e.value,
        imageUrl: null,
        prepMinutes: null,
      );
    }).toList();
  }

  Future<void> _finish() async {
    if (!AuthService.instance.isLoggedIn) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (_loadingRating) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (_userRating != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nice work — you already left a review for this recipe.'), backgroundColor: _wellGreen),
        );
        Navigator.pop(context);
      }
      return;
    }

    int? stars;
    final reviewController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('How did it turn out?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Leave a quick rating for this recipe.'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final st = i + 1;
                        return IconButton(
                          onPressed: () => setLocal(() => stars = st),
                          icon: Icon(
                            (stars ?? 0) >= st ? Icons.star : Icons.star_border,
                            color: const Color(0xFFF9BD21),
                            size: 36,
                          ),
                        );
                      }),
                    ),
                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Optional review…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: stars != null && stars! >= 1 ? () => Navigator.pop(ctx, true) : null,
                  style: FilledButton.styleFrom(backgroundColor: _wellGreen),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true && stars != null && mounted) {
      try {
        await RatingService.instance.submitRating(
          recipeId: widget.recipe.id,
          rating: stars!,
          comment: reviewController.text.trim().isEmpty ? null : reviewController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks for your feedback!'), backgroundColor: _wellGreen),
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

    reviewController.dispose();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _pages[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: _wellGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  'Step ${_index + 1} of ${_pages.length}',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (page.prepMinutes != null && page.prepMinutes! > 0)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text('${page.prepMinutes} min'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final p = _pages[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        p.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: _wellGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.instructions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          p.instructions,
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                        ),
                      ],
                      if (p.imageUrl != null && p.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                if (_index > 0)
                  OutlinedButton(
                    onPressed: () {
                      _pageController.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                    },
                    child: const Text('Previous'),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _wellGreen,
                    minimumSize: const Size(160, 48),
                  ),
                  onPressed: () {
                    if (_index < _pages.length - 1) {
                      _pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                    } else {
                      _finish();
                    }
                  },
                  child: Text(_index < _pages.length - 1 ? 'Next' : 'Finish cooking'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
