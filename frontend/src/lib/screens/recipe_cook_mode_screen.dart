import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wellnest/models/recipe.dart';
import 'package:wellnest/theme/app_theme.dart';
import 'package:wellnest/models/recipe_rating.dart';
import 'package:wellnest/services/auth_service.dart';
import 'package:wellnest/services/rating_service.dart';
import 'package:wellnest/utils/media_url.dart';

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
  /// Checklist (page 0) → steps (page 1). Null when there is no checklist.
  PageController? _phaseController;
  int _phaseIndex = 0;

  late final List<_CookPage> _pages;
  int _index = 0;
  RecipeRating? _userRating;
  bool _loadingRating = true;

  /// Ingredient lines for prep checklist (empty → skip checklist automatically).
  List<String> _checklistLines = [];
  List<bool> _ingredientChecked = [];

  static const Color _wellGreen = Color(0xFF097333);
  static const double _navButtonHeight = 52;

  static const Duration _pageAnimDuration = Duration(milliseconds: 420);
  static const Curve _pageAnimCurve = Curves.easeOutCubic;

  bool get _showChecklistPhase =>
      _checklistLines.isNotEmpty && _phaseIndex == 0;

  bool get _allIngredientsChecked =>
      _checklistLines.isEmpty ||
      _ingredientChecked.every((c) => c);

  /// Progress includes optional checklist as first segment (matches recipe form bar style).
  double _overallProgressValue() {
    final n = _pages.length;
    if (n == 0) return 1.0;
    final hasChecklist = _checklistLines.isNotEmpty;
    final totalSegments = hasChecklist ? n + 1 : n;
    if (hasChecklist && _showChecklistPhase) {
      return 1.0 / totalSegments;
    }
    if (hasChecklist) {
      return (_index + 2) / totalSegments;
    }
    return (_index + 1) / totalSegments;
  }

  bool get _canGoBackFromSteps {
    if (_index > 0) {
      return true;
    }
    if (_checklistLines.isNotEmpty && _phaseIndex == 1) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _pages = _buildCookPages(widget.recipe);
    _pageController = PageController();
    final ing = widget.recipe.ingredients;
    if (ing != null && ing.isNotEmpty) {
      _checklistLines = ing.map((e) => e.displayLine).toList();
      _ingredientChecked = List<bool>.filled(_checklistLines.length, false);
      _phaseController = PageController();
      _phaseIndex = 0;
    }
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
    _phaseController?.dispose();
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
            final theme = Theme.of(context);
            final cs = theme.colorScheme;
            const reviewRadius = 14.0;
            final fieldBorder = OutlineInputBorder(
              borderRadius: BorderRadius.circular(reviewRadius),
              borderSide: BorderSide(color: _wellGreen.withValues(alpha: 0.28)),
            );
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.discoverHeroFor(context),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'How did it turn out?',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: kFontHelveticaNow,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Leave a quick rating for this recipe.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFamily: kFontHelveticaNow,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            final st = i + 1;
                            return IconButton(
                              onPressed: () => setLocal(() => stars = st),
                              icon: Icon(
                                (stars ?? 0) >= st
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFF9BD21),
                                size: 38,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: reviewController,
                          maxLength: 1000,
                          maxLines: 3,
                          style: TextStyle(
                            fontFamily: kFontHelveticaNow,
                            color: cs.onSurface,
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Optional review…',
                            hintStyle: TextStyle(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                              fontFamily: kFontHelveticaNow,
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerHigh,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: fieldBorder,
                            enabledBorder: fieldBorder,
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(reviewRadius),
                              borderSide:
                                  const BorderSide(color: _wellGreen, width: 1.5),
                            ),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: TextButton.styleFrom(
                                foregroundColor: _wellGreen,
                              ),
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  fontFamily: kFontHelveticaNow,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            FilledButton(
                              onPressed: stars != null && stars! >= 1
                                  ? () => Navigator.pop(ctx, true)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _wellGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Submit',
                                style: TextStyle(
                                  fontFamily: kFontHelveticaNow,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

    if (mounted) {
      Navigator.pop(context);
    }
    // Dispose after routes/dialogs tear down — avoids TextField using controller mid-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reviewController.dispose();
    });
  }

  /// Font only — button themes supply [Color] (including disabled).
  static const TextStyle _navButtonTextStyle = TextStyle(
    fontFamily: kFontHelveticaNow,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  void _goToStepsFromChecklist() {
    _phaseController?.animateToPage(
      1,
      duration: _pageAnimDuration,
      curve: _pageAnimCurve,
    );
  }

  void _onPreviousFromSteps() {
    if (_index == 0 &&
        _checklistLines.isNotEmpty &&
        _phaseController != null &&
        _phaseIndex == 1) {
      _phaseController!.animateToPage(
        0,
        duration: _pageAnimDuration,
        curve: _pageAnimCurve,
      );
      return;
    }
    _pageController.previousPage(
      duration: _pageAnimDuration,
      curve: _pageAnimCurve,
    );
  }

  Widget _prepTimeChip(BuildContext context, int minutes) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _wellGreen.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.28 : 0.06,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: _wellGreen),
          const SizedBox(width: 6),
          Text(
            '$minutes min',
            style: TextStyle(
              fontFamily: kFontHelveticaNow,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: wellnestHeadingGreen(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientChecklist(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Gather your ingredients',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: wellnestHeadingGreen(context),
              fontWeight: FontWeight.w700,
              fontFamily: kFontHelveticaNow,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check off each item you already have. Continue when your prep is complete.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
              fontFamily: kFontHelveticaNow,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _ingredientChecked =
                      List<bool>.filled(_checklistLines.length, true);
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: _wellGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Select all',
                style: TextStyle(
                  fontFamily: kFontHelveticaNow,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Theme(
            data: theme.copyWith(
              checkboxTheme: CheckboxThemeData(
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return _wellGreen;
                  }
                  return null;
                }),
                checkColor: WidgetStateProperty.all(Colors.white),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: wellnestOutlineColor(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.35 : 0.04,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(_checklistLines.length, (i) {
                  return CheckboxListTile(
                    value: _ingredientChecked[i],
                    onChanged: (v) {
                      setState(() => _ingredientChecked[i] = v ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      _checklistLines[i],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                        fontFamily: kFontHelveticaNow,
                        color: cs.onSurface,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsPageView(ThemeData theme, ColorScheme cs) {
    return PageView.builder(
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
                  color: wellnestHeadingGreen(context),
                  fontWeight: FontWeight.w700,
                  fontFamily: kFontHelveticaNow,
                ),
              ),
              if (p.instructions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  p.instructions,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    fontFamily: kFontHelveticaNow,
                    color: cs.onSurface,
                  ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final page = _pages.isEmpty ? null : _pages[_index];
    final progress = _overallProgressValue().clamp(0.0, 1.0);
    final last = _pages.isNotEmpty && _index >= _pages.length - 1;
    final primaryLabel = last ? 'Finish cooking' : 'Next';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: theme.brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        foregroundColor: cs.onSurface,
        iconTheme: IconThemeData(color: cs.onSurface),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          _showChecklistPhase ? 'Before you start' : 'Instructions',
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            fontFamily: kFontHelveticaNow,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.discoverHeroFor(context),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: _wellGreen.withValues(alpha: 0.15),
                      color: _wellGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showChecklistPhase
                              ? 'Ingredient checklist'
                              : 'Step ${_index + 1} of ${_pages.length}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontFamily: kFontHelveticaNow,
                          ),
                        ),
                      ),
                      if (!_showChecklistPhase &&
                          page != null &&
                          page.prepMinutes != null &&
                          page.prepMinutes! > 0)
                        _prepTimeChip(context, page.prepMinutes!),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _phaseController == null
                  ? _buildStepsPageView(theme, cs)
                  : PageView(
                      controller: _phaseController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) => setState(() => _phaseIndex = i),
                      children: [
                        _buildIngredientChecklist(context, theme, cs),
                        _buildStepsPageView(theme, cs),
                      ],
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _showChecklistPhase
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextButton(
                          onPressed: _goToStepsFromChecklist,
                          style: TextButton.styleFrom(
                            foregroundColor: cs.onSurfaceVariant,
                          ),
                          child: Text(
                            'Skip checklist',
                            style: TextStyle(
                              fontFamily: kFontHelveticaNow,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _wellGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: cs.surfaceContainerHighest,
                            disabledForegroundColor: cs.onSurfaceVariant,
                            minimumSize: const Size.fromHeight(_navButtonHeight),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed:
                              _allIngredientsChecked ? _goToStepsFromChecklist : null,
                          child: const Text(
                            'Continue to steps',
                            style: _navButtonTextStyle,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(_navButtonHeight),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              side: BorderSide(
                                color: _wellGreen.withValues(alpha: 0.55),
                              ),
                              foregroundColor: _wellGreen,
                              disabledForegroundColor:
                                  cs.onSurface.withValues(alpha: 0.38),
                            ),
                            onPressed:
                                _canGoBackFromSteps ? _onPreviousFromSteps : null,
                            child: const Text(
                              'Previous',
                              style: _navButtonTextStyle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _wellGreen,
                              foregroundColor: Colors.white,
                              minimumSize:
                                  const Size.fromHeight(_navButtonHeight),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            onPressed: () {
                              if (_index < _pages.length - 1) {
                                _pageController.nextPage(
                                  duration: _pageAnimDuration,
                                  curve: _pageAnimCurve,
                                );
                              } else {
                                _finish();
                              }
                            },
                            child: Text(
                              primaryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _navButtonTextStyle,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
