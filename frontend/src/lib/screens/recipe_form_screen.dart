import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/services/category_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/utils/media_url.dart';

/// Selected row in category dropdown — same wash as [RecipeRankingScreen] filters.
Color _recipeCategoryDropdownSelectedWash() => Color.alphaBlend(
  kPrimaryGreen.withValues(alpha: 0.12),
  Colors.grey.shade100,
);

/// Recipe wizard uses a white canvas and subtle gray bordered fields (not app cream/warm surface).
const Color _recipeFormSurface = Colors.white;
const Color _recipeFormFieldFill = Color(0xFFF3F4F6);
const Color _recipeFormFieldBorder = Color(0xFFBDBDBD);

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipe;
  final bool asModal;

  const RecipeFormScreen({super.key, this.recipe, this.asModal = false});

  /// Shows the recipe form as a modal bottom sheet. Returns true if saved.
  static Future<bool?> showAsModal(BuildContext context, {Recipe? recipe}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: BoxDecoration(
              gradient: AppGradients.discoverHeroFadeTo(_recipeFormSurface),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: RecipeFormScreen(recipe: recipe, asModal: true),
          ),
        );
      },
    );
  }

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  static const int _kWizardSteps = 4;
  static const int _kMaxRecipeImages = 10;
  static const int _kMakeNewCategoryValue = -1;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '30');
  final _newCategoryController = TextEditingController();

  int _wizardIndex = 0;
  final List<TextEditingController> _ingredientControllers = [];
  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _useCustomCategory = false;
  PrepTimingMode _timingMode = PrepTimingMode.overall;

  List<_DraftStep> _draftSteps = [];

  bool _loadingCategories = true;
  bool _hydrating = false;
  bool _saving = false;
  String? _submitError;
  String? _loadError;
  bool _pickingImage = false;
  bool _hydratingGallery = false;
  final ImagePicker _picker = ImagePicker();

  final List<_RecipeImgSlot> _imageSlots = [];

  bool get _isEditing => widget.recipe != null;

  InputDecoration _recipeFieldDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    bool dense = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(10);
    final side = const BorderSide(color: _recipeFormFieldBorder, width: 1);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: _recipeFormFieldFill,
      isDense: dense,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: dense ? 10 : 14,
      ),
      border: OutlineInputBorder(borderRadius: radius, borderSide: side),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: side),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
    );
  }

  InputDecoration _categoryDropdownDecoration(BuildContext context) {
    return InputDecoration(
      labelText: 'Category',
      hintText: _loadingCategories
          ? 'Loading categories...'
          : 'Select a category',
      hintStyle: helveticaNow(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: kCaptionGray,
      ),
      labelStyle: helveticaNow(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: kCaptionGray,
      ),
      floatingLabelStyle: helveticaNow(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryGreen,
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: wellnestOutlineColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: wellnestOutlineColor(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  /// Softer surfaces + no primary tint on popup menus — matches [RecipeRankingScreen].
  ThemeData _categoryDropdownTheme(BuildContext context) {
    final base = Theme.of(context);
    final outline = wellnestOutlineColor(context);
    final menuShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      side: BorderSide(color: outline),
    );
    final wash = _recipeCategoryDropdownSelectedWash();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: wash,
        onPrimary: kBodyTextDark,
        primaryContainer: wash,
        onPrimaryContainer: kBodyTextDark,
      ),
      focusColor: wash,
      splashColor: AppColors.primaryGreen.withValues(alpha: 0.08),
      highlightColor: wash,
      canvasColor: Colors.white,
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: menuShape,
        textStyle: helveticaNow(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: kBodyTextDark,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(
            Colors.black.withValues(alpha: 0.08),
          ),
          shape: WidgetStateProperty.all(menuShape),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          ),
        ),
      ),
    );
  }

  TextStyle get _categoryDropdownValueStyle => helveticaNow(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: kPrimaryGreen,
  );

  TextStyle get _categoryDropdownMenuItemStyle => helveticaNow(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: kBodyTextDark,
  );

  @override
  void initState() {
    super.initState();
    _draftSteps = [_DraftStep()];
    _ingredientControllers.add(TextEditingController());
    _loadCategories();
    if (_isEditing && widget.recipe != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateForEdit());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _newCategoryController.dispose();
    for (final c in _ingredientControllers) {
      c.dispose();
    }
    for (final s in _draftSteps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _hydrateForEdit() async {
    if (widget.recipe == null) return;
    setState(() {
      _hydrating = true;
      _loadError = null;
    });
    try {
      final full = await RecipeService.instance.fetchRecipe(widget.recipe!.id);
      if (!mounted) return;
      for (final s in _draftSteps) {
        s.dispose();
      }
      _draftSteps = [];
      _titleController.text = full.title;
      _descriptionController.text = full.description ?? '';
      _prepTimeController.text = '${full.prepTime > 0 ? full.prepTime : 30}';
      _selectedCategoryId = full.categoryId;
      _useCustomCategory = false;
      _newCategoryController.clear();
      _timingMode = full.prepTimingMode;

      for (final c in _ingredientControllers) {
        c.dispose();
      }
      _ingredientControllers.clear();
      if (full.ingredients != null && full.ingredients!.isNotEmpty) {
        for (final i in full.ingredients!) {
          _ingredientControllers.add(
            TextEditingController(text: i.displayLine),
          );
        }
      }
      if (_ingredientControllers.isEmpty) {
        _ingredientControllers.add(TextEditingController());
      }

      if (full.steps != null && full.steps!.isNotEmpty) {
        for (final si in full.steps!) {
          final d = _DraftStep(
            serverId: si.id,
            serverImageId: si.image?.id,
            serverImageUrl: si.image?.url,
          );
          d.titleController.text = si.title ?? '';
          d.instructionsController.text = si.instructions ?? '';
          if (si.prepTimeMinutes != null) {
            d.prepController.text = '${si.prepTimeMinutes}';
          }
          _draftSteps.add(d);
        }
      } else {
        _draftSteps = [_DraftStep()];
        if (full.instructions.trim().isNotEmpty) {
          _draftSteps.first.instructionsController.text = full.instructions;
        }
      }

      setState(() {
        _hydratingGallery = true;
        _hydrating = false;
      });

      _imageSlots.clear();
      for (final img in full.galleryImages) {
        _imageSlots.add(_RecipeImgSlot.network(serverId: img.id, url: img.url));
      }
      if (mounted) setState(() => _hydratingGallery = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hydrating = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _loadError = null;
    });
    try {
      final list = await CategoryService.instance.fetchCategories(admin: false);
      if (!mounted) return;
      setState(() {
        _categories = list;
        // New recipes: require an explicit choice — no default category.
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loadingCategories = false;
      });
    }
  }

  List<Map<String, dynamic>> _stepsPayload() {
    return _draftSteps.map((s) {
      final m = <String, dynamic>{};
      if (s.serverId != null) m['id'] = s.serverId;
      final t = s.titleController.text.trim();
      final ins = s.instructionsController.text.trim();
      if (t.isNotEmpty) m['title'] = t;
      if (ins.isNotEmpty) m['instructions'] = ins;
      if (_timingMode == PrepTimingMode.perStep) {
        final pm = int.tryParse(s.prepController.text.trim());
        if (pm != null && pm >= 0) {
          m['prep_time_minutes'] = pm;
        }
      }
      return m;
    }).toList();
  }

  bool _validateBasics() {
    if ((_titleController.text.trim()).isEmpty) return false;
    if (_useCustomCategory) {
      if (_newCategoryController.text.trim().isEmpty) return false;
    } else if (_selectedCategoryId == null) {
      return false;
    }
    if (_timingMode == PrepTimingMode.overall) {
      final n = int.tryParse(_prepTimeController.text.trim());
      if (n == null || n < 1) return false;
    }
    return true;
  }

  Future<int> _resolveCategoryId() async {
    if (!_useCustomCategory) {
      final id = _selectedCategoryId;
      if (id == null) throw Exception('Select a category.');
      return id;
    }

    final category = await CategoryService.instance.findOrCreateForRecipe(
      _newCategoryController.text.trim(),
    );
    if (mounted) {
      setState(() {
        if (!_categories.any((c) => c.id == category.id)) {
          _categories = [..._categories, category]
            ..sort((a, b) => a.name.compareTo(b.name));
        }
        _selectedCategoryId = category.id;
      });
    }
    return category.id;
  }

  List<Category> _categorySuggestions() {
    final typed = _newCategoryController.text.trim();
    if (typed.length < 2) return const [];

    final typedLower = typed.toLowerCase();
    final maxDistance = typedLower.length <= 5 ? 1 : 2;
    final matches = _categories.where((category) {
      final name = category.name.trim();
      if (name == typed) return false;

      final nameLower = name.toLowerCase();
      if (nameLower == typedLower) return true;
      if (nameLower.startsWith(typedLower) ||
          typedLower.startsWith(nameLower)) {
        return true;
      }
      return _levenshteinDistance(typedLower, nameLower) <= maxDistance;
    }).toList();

    matches.sort((a, b) {
      final da = _levenshteinDistance(typedLower, a.name.toLowerCase());
      final db = _levenshteinDistance(typedLower, b.name.toLowerCase());
      if (da != db) return da.compareTo(db);
      return a.name.compareTo(b.name);
    });
    return matches.take(3).toList();
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 0; i < a.length; i++) {
      final current = <int>[i + 1];
      for (var j = 0; j < b.length; j++) {
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace = previous[j] + (a[i] == b[j] ? 0 : 1);
        current.add([insert, delete, replace].reduce((x, y) => x < y ? x : y));
      }
      previous = current;
    }
    return previous.last;
  }

  bool _validateIngredients() {
    final filled = _ingredientControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    return filled >= 1;
  }

  bool _validateSteps() {
    for (final s in _draftSteps) {
      final t = s.titleController.text.trim();
      final ins = s.instructionsController.text.trim();
      if (t.isNotEmpty || ins.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _pickStepPhoto(int index) async {
    if (index < 0 || index >= _draftSteps.length) return;
    try {
      final f = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (f != null && mounted) {
        setState(() {
          _draftSteps[index].localImage = f;
          _draftSteps[index].removeServerImage = false;
        });
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  Future<void> _pickImages() async {
    if (_pickingImage) return;
    final remain = _kMaxRecipeImages - _imageSlots.length;
    if (remain <= 0) return;
    setState(() => _pickingImage = true);
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (!mounted) return;
      setState(() {
        for (final f in picked.take(remain)) {
          _imageSlots.add(_RecipeImgSlot.local(f));
        }
      });
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick images: $e'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _removeImageSlot(int index) async {
    final slot = _imageSlots[index];
    if (slot.serverId != null && _isEditing && widget.recipe != null) {
      try {
        await RecipeService.instance.deleteRecipeImage(
          widget.recipe!.id,
          slot.serverId!,
        );
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }
    }
    setState(() => _imageSlots.removeAt(index));
  }

  void _onReorderImages(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _imageSlots.removeAt(oldIndex);
      _imageSlots.insert(newIndex, item);
    });
  }

  Future<void> _syncStepPhotosAfterSave(int recipeId) async {
    final full = await RecipeService.instance.fetchRecipe(recipeId);
    final steps = full.steps;
    if (steps == null || steps.length != _draftSteps.length) return;
    for (var i = 0; i < _draftSteps.length; i++) {
      final local = _draftSteps[i].localImage;
      if (local != null && i < steps.length) {
        await RecipeService.instance.uploadRecipeStepImage(
          recipeId,
          steps[i].id,
          local,
        );
      }
    }
  }

  Future<void> _submit() async {
    _submitError = null;
    if (!_validateBasics() || !_validateIngredients() || !_validateSteps()) {
      setState(() => _submitError = 'Please complete all required fields.');
      return;
    }
    final ingredients = _ingredientControllers
        .map((c) => c.text.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => <String, dynamic>{'name': line})
        .toList();

    final stepsPayload = _stepsPayload();
    final prep = int.tryParse(_prepTimeController.text.trim()) ?? 30;

    setState(() => _saving = true);
    try {
      final categoryId = await _resolveCategoryId();
      int recipeId;
      if (_isEditing) {
        recipeId = widget.recipe!.id;
        await RecipeService.instance.updateRecipe(
          recipeId,
          categoryId: categoryId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          prepTime: _timingMode == PrepTimingMode.overall ? prep : null,
          prepTimingMode: _timingMode,
          ingredients: ingredients,
          steps: stepsPayload,
        );
        final ids = <int>[];
        for (final slot in _imageSlots) {
          if (slot.serverId != null) {
            ids.add(slot.serverId!);
          } else if (slot.file != null) {
            final nid = await RecipeService.instance.uploadRecipeImage(
              recipeId,
              slot.file!,
            );
            ids.add(nid);
          }
        }
        if (ids.isNotEmpty) {
          await RecipeService.instance.reorderRecipeImages(recipeId, ids);
        }
        await _syncStepPhotosAfterSave(recipeId);
      } else {
        recipeId = await RecipeService.instance.createRecipe(
          categoryId: categoryId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          prepTime: _timingMode == PrepTimingMode.overall ? prep : null,
          prepTimingMode: _timingMode,
          ingredients: ingredients,
          steps: stepsPayload,
        );
        final ids = <int>[];
        for (final slot in _imageSlots) {
          if (slot.file != null) {
            final nid = await RecipeService.instance.uploadRecipeImage(
              recipeId,
              slot.file!,
            );
            ids.add(nid);
          }
        }
        if (ids.length > 1) {
          await RecipeService.instance.reorderRecipeImages(recipeId, ids);
        }
        await _syncStepPhotosAfterSave(recipeId);
      }
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Recipe updated' : 'Recipe created'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      if (!context.mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  void _goNext() {
    if (_wizardIndex == 0 && !_validateBasics()) {
      setState(
        () =>
            _submitError = 'Add a title, category, and prep time (if overall).',
      );
      return;
    }
    if (_wizardIndex == 1 && !_validateIngredients()) {
      setState(() => _submitError = 'Add at least one ingredient.');
      return;
    }
    if (_wizardIndex == 2 && !_validateSteps()) {
      setState(
        () => _submitError = 'Each step needs a title and/or instructions.',
      );
      return;
    }
    setState(() {
      _submitError = null;
      _wizardIndex = (_wizardIndex + 1).clamp(0, _kWizardSteps - 1);
    });
  }

  void _goBack() {
    setState(() {
      _submitError = null;
      _wizardIndex = (_wizardIndex - 1).clamp(0, _kWizardSteps - 1);
    });
  }

  Widget _buildCategorySelector(BuildContext context) {
    final selectedDropdownValue = _useCustomCategory
        ? _kMakeNewCategoryValue
        : (_categories.any((c) => c.id == _selectedCategoryId)
              ? _selectedCategoryId
              : null);
    final suggestions = _categorySuggestions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: _categoryDropdownTheme(context),
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            value: selectedDropdownValue,
            decoration: _categoryDropdownDecoration(context),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            style: _categoryDropdownValueStyle,
            iconEnabledColor: kPrimaryGreen,
            items: [
              DropdownMenuItem(
                value: _kMakeNewCategoryValue,
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: kBodyTextDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Make New category',
                        style: _categoryDropdownMenuItemStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ..._categories.map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    c.name,
                    style: _categoryDropdownMenuItemStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: _loadingCategories
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() {
                      if (value == _kMakeNewCategoryValue) {
                        _useCustomCategory = true;
                      } else {
                        _useCustomCategory = false;
                        _selectedCategoryId = value;
                      }
                    });
                  },
          ),
        ),
        const SizedBox(height: 12),
        if (_useCustomCategory)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _newCategoryController,
                decoration: _recipeFieldDecoration(
                  context,
                  labelText: 'New category',
                  hintText: 'Example: Breakfast',
                ),
                maxLength: 255,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              if (suggestions.isNotEmpty) ...[
                Text(
                  'Did you mean:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: suggestions
                      .map(
                        (category) => ActionChip(
                          label: Text(category.name),
                          onPressed: () {
                            setState(() {
                              _selectedCategoryId = category.id;
                              _useCustomCategory = false;
                              _newCategoryController.clear();
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        if (_useCustomCategory)
          Text(
            'Same spelling as an existing category counts as that category (capitalization does not matter).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildBasicsStep(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          'Basics',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _buildCategorySelector(context),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: _recipeFieldDecoration(
            context,
            labelText: 'Recipe title',
          ),
          maxLength: 255,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          decoration: _recipeFieldDecoration(
            context,
            labelText: 'Description',
            hintText: 'Optional — what makes this recipe special?',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        _buildCoverPhotosSection(context, cs),
        const SizedBox(height: 16),
        Text(
          'Prep time',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SegmentedButton<PrepTimingMode>(
          segments: const [
            ButtonSegment(
              value: PrepTimingMode.overall,
              label: Text('Overall'),
              icon: Icon(Icons.schedule),
            ),
            ButtonSegment(
              value: PrepTimingMode.perStep,
              label: Text('Per step'),
              icon: Icon(Icons.list_alt),
            ),
          ],
          selected: {_timingMode},
          onSelectionChanged: (s) {
            setState(() => _timingMode = s.first);
          },
        ),
        const SizedBox(height: 12),
        if (_timingMode == PrepTimingMode.overall)
          TextField(
            controller: _prepTimeController,
            decoration: _recipeFieldDecoration(
              context,
              labelText: 'Total prep/cook time (minutes)',
              hintText: 'e.g. 30',
            ),
            keyboardType: TextInputType.number,
          )
        else
          Text(
            'Enter optional minutes on each step in the next section. Total time is summed automatically.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildIngredientsStep(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          'Ingredients',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text(
          'One ingredient per line — include amount and unit in the text if you like.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        ...List.generate(_ingredientControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ingredientControllers[i],
                    decoration: _recipeFieldDecoration(
                      context,
                      hintText: 'e.g. 5 cloves garlic, 2 cups water',
                    ),
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: cs.secondary,
                    size: 22,
                  ),
                  onPressed: _ingredientControllers.length > 1
                      ? () => setState(() {
                          final removed = _ingredientControllers.removeAt(i);
                          removed.dispose();
                        })
                      : null,
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(
            () => _ingredientControllers.add(TextEditingController()),
          ),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add ingredient line'),
        ),
      ],
    );
  }

  Widget _buildStepsStep(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          'Steps',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'Each step needs a title and/or instructions. Instruction text is optional per step.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _draftSteps.length,
          onReorder: (oldI, newI) {
            setState(() {
              if (newI > oldI) newI -= 1;
              final row = _draftSteps.removeAt(oldI);
              _draftSteps.insert(newI, row);
            });
          },
          itemBuilder: (context, index) {
            final s = _draftSteps[index];
            return Card(
              key: ValueKey('step_${s.serverId}_$index'),
              color: _recipeFormSurface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: _recipeFormFieldBorder, width: 1),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              Icons.drag_handle,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          'Step ${index + 1}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        if (_draftSteps.length > 1)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: cs.secondary,
                            ),
                            onPressed: () => setState(() {
                              s.dispose();
                              _draftSteps.removeAt(index);
                            }),
                          ),
                      ],
                    ),
                    TextField(
                      controller: s.titleController,
                      decoration: _recipeFieldDecoration(
                        context,
                        labelText: 'Step title',
                        hintText: 'Optional if you add instructions',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: s.instructionsController,
                      decoration: _recipeFieldDecoration(
                        context,
                        labelText: 'Instructions (optional)',
                        hintText: 'What do you do in this step?',
                      ),
                      minLines: 2,
                      maxLines: 6,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_timingMode == PrepTimingMode.perStep) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: s.prepController,
                        decoration: _recipeFieldDecoration(
                          context,
                          labelText: 'Minutes for this step (optional)',
                          hintText: 'e.g. 5',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickStepPhoto(index),
                          icon: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18,
                          ),
                          label: Text(
                            s.localImage != null ||
                                    (s.serverImageUrl != null &&
                                        !s.removeServerImage)
                                ? 'Change step photo'
                                : 'Add step photo (optional)',
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            s.localImage = null;
                            s.removeServerImage = true;
                          }),
                          child: const Text('Photo later'),
                        ),
                      ],
                    ),
                    if (s.localImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          child: FutureBuilder<Uint8List>(
                            future: s.localImage!.readAsBytes(),
                            builder: (context, snap) {
                              if (snap.hasData) {
                                return Image.memory(
                                  snap.data!,
                                  height: 100,
                                  fit: BoxFit.cover,
                                );
                              }
                              return const SizedBox(height: 40);
                            },
                          ),
                        ),
                      )
                    else if (s.serverImageUrl != null && !s.removeServerImage)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          child: Image.network(
                            resolveStorageDisplayUrl(s.serverImageUrl!) ??
                                s.serverImageUrl!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        TextButton.icon(
          onPressed: () => setState(() => _draftSteps.add(_DraftStep())),
          icon: const Icon(Icons.add),
          label: const Text('Add step'),
        ),
      ],
    );
  }

  Widget _buildCoverPhotosSection(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Cover photos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Optional — first photo is the list thumbnail. Drag to reorder.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        if (_hydratingGallery)
          SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(color: cs.primary)),
          )
        else if (_imageSlots.isNotEmpty) ...[
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _onReorderImages,
            children: [
              for (var i = 0; i < _imageSlots.length; i++)
                _buildRecipeImageTile(i, cs),
            ],
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed:
              (_pickingImage ||
                  _imageSlots.length >= _kMaxRecipeImages ||
                  _hydratingGallery)
              ? null
              : _pickImages,
          icon: _pickingImage
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: cs.primary,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _imageSlots.isEmpty ? 'Add cover photos' : 'Add more photos',
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context, ColorScheme cs) {
    final summarySteps = _draftSteps.length;
    final ingCount = _ingredientControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;
    final prepLabel = _timingMode == PrepTimingMode.overall
        ? '${_prepTimeController.text.trim().isEmpty ? '—' : _prepTimeController.text.trim()} min'
        : 'Per step';

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          'Review your recipe',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: _recipeFormFieldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleController.text.trim().isEmpty
                    ? 'Untitled recipe'
                    : _titleController.text.trim(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_descriptionController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _descriptionController.text.trim(),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: _recipeFormFieldBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _reviewStatSegment(
                    context,
                    cs,
                    icon: Icons.shopping_basket_outlined,
                    value: '$ingCount',
                    label: ingCount == 1 ? 'Ingredient' : 'Ingredients',
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _recipeFormFieldBorder,
                ),
                Expanded(
                  child: _reviewStatSegment(
                    context,
                    cs,
                    icon: Icons.format_list_numbered_rounded,
                    value: '$summarySteps',
                    label: summarySteps == 1 ? 'Step' : 'Steps',
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _recipeFormFieldBorder,
                ),
                Expanded(
                  child: _reviewStatSegment(
                    context,
                    cs,
                    icon: Icons.schedule_rounded,
                    value: prepLabel,
                    label: _timingMode == PrepTimingMode.overall
                        ? 'Prep time'
                        : 'Timing',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.collections_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Cover photos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_hydratingGallery)
          SizedBox(
            height: 88,
            child: Center(child: CircularProgressIndicator(color: cs.primary)),
          )
        else if (_imageSlots.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imageSlots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildReviewPhotoThumb(index, cs);
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  Icons.hide_image_outlined,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No cover photos yet — add them in Basics (step 1).',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.playlist_add_check_rounded, size: 22, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Cooking steps',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List.generate(_draftSteps.length, (i) {
          final s = _draftSteps[i];
          final titleText = s.titleController.text.trim();
          final inst = s.instructionsController.text.trim();
          final displayTitle = titleText.isNotEmpty
              ? titleText
              : 'Step ${i + 1}';
          final hasThumb =
              s.localImage != null ||
              (s.serverImageUrl != null && !s.removeServerImage);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _recipeFormFieldBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                        ),
                        if (inst.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            inst,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                          ),
                        ],
                        if (_timingMode == PrepTimingMode.perStep &&
                            s.prepController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${s.prepController.text.trim()} min',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasThumb) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: s.localImage != null
                          ? FutureBuilder<Uint8List>(
                              future: s.localImage!.readAsBytes(),
                              builder: (context, snap) {
                                if (snap.hasData) {
                                  return Image.memory(
                                    snap.data!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Image.network(
                              resolveStorageDisplayUrl(s.serverImageUrl!) ??
                                  s.serverImageUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.image_not_supported_outlined,
                                color: cs.outline,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'Tap Create recipe when everything looks good. You can edit the recipe later.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _reviewStatSegment(
    BuildContext context,
    ColorScheme cs, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    final valueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(value, maxLines: 1, style: valueStyle),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPhotoThumb(int index, ColorScheme colorScheme) {
    final slot = _imageSlots[index];
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: slot.file != null
                ? FutureBuilder<Uint8List>(
                    future: slot.file!.readAsBytes(),
                    builder: (context, snap) {
                      if (snap.hasData) {
                        return Image.memory(snap.data!, fit: BoxFit.cover);
                      }
                      return ColoredBox(
                        color: colorScheme.surfaceContainerHighest,
                      );
                    },
                  )
                : Image.network(
                    resolveStorageDisplayUrl(slot.url!) ?? slot.url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
          ),
          if (index == 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Cover',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecipeImageTile(int index, ColorScheme colorScheme) {
    final slot = _imageSlots[index];
    final child = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      height: 120,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (slot.file != null)
            FutureBuilder<Uint8List>(
              future: slot.file!.readAsBytes(),
              builder: (context, snap) {
                if (snap.hasData) {
                  return Image.memory(
                    snap.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  );
                }
                return Container(color: colorScheme.surfaceContainerHighest);
              },
            )
          else if (slot.url != null)
            Image.network(
              resolveStorageDisplayUrl(slot.url!) ?? slot.url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close, size: 20),
              onPressed: _saving ? null : () => _removeImageSlot(index),
            ),
          ),
          if (index == 0)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Cover',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );

    return ReorderableDelayedDragStartListener(
      key: ValueKey(
        '${slot.serverId ?? 'n'}_${slot.file?.path ?? ''}_${slot.url ?? ''}_$index',
      ),
      index: index,
      child: child,
    );
  }

  Widget _buildWizardBody(ColorScheme cs) {
    switch (_wizardIndex) {
      case 0:
        return _buildBasicsStep(context, cs);
      case 1:
        return _buildIngredientsStep(context, cs);
      case 2:
        return _buildStepsStep(context, cs);
      case 3:
      default:
        return _buildReviewStep(context, cs);
    }
  }

  Widget _buildShell() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_loadingCategories || _hydrating) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _isEditing ? 'Edit recipe' : 'New recipe',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (widget.asModal)
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                      style: IconButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_wizardIndex + 1) / _kWizardSteps,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 4),
              Text(
                'Step ${_wizardIndex + 1} of $_kWizardSteps',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (_loadError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_loadError!, style: TextStyle(color: cs.secondary)),
                  TextButton.icon(
                    onPressed: _loadCategories,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        if (_submitError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(_submitError!, style: TextStyle(color: cs.secondary)),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildWizardBody(cs),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Row(
            children: [
              if (_wizardIndex > 0)
                OutlinedButton(
                  onPressed: _saving ? null : _goBack,
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (_wizardIndex < _kWizardSteps - 1)
                FilledButton(
                  onPressed: _saving ? null : _goNext,
                  child: const Text('Next'),
                )
              else
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_isEditing ? 'Save recipe' : 'Create recipe'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.asModal) {
      return _buildShell();
    }

    final topOverlap = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          _isEditing ? 'Edit recipe' : 'New recipe',
          style: theme.textTheme.titleLarge,
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.discoverHeroFadeTo(_recipeFormSurface),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.only(top: topOverlap),
            child: _buildShell(),
          ),
        ),
      ),
    );
  }
}

class _DraftStep {
  _DraftStep({this.serverId, int? serverImageId, String? serverImageUrl})
    : serverImageId = serverImageId,
      serverImageUrl = serverImageUrl;

  final int? serverId;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();
  final TextEditingController prepController = TextEditingController();

  XFile? localImage;
  int? serverImageId;
  String? serverImageUrl;
  bool removeServerImage = false;

  void dispose() {
    titleController.dispose();
    instructionsController.dispose();
    prepController.dispose();
  }
}

class _RecipeImgSlot {
  _RecipeImgSlot.network({required this.serverId, required this.url})
    : file = null;

  _RecipeImgSlot.local(this.file) : serverId = null, url = null;

  final int? serverId;
  final XFile? file;
  final String? url;
}
