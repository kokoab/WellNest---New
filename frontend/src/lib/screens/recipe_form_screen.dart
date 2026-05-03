import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/services/category_service.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/theme/app_theme.dart';

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
        final cardColor = Theme.of(ctx).cardColor;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(ctx).size.height * 0.92,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
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

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _prepTimeController = TextEditingController();

  List<Map<String, String>> _ingredients = []; // [{name, quantity, unit}]

  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _loadingCategories = true;
  bool _saving = false;
  String? _submitError;
  String? _loadError;
  XFile? _pickedImage;
  bool _pickingImage = false;
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _titleController.text = widget.recipe!.title;
      _instructionsController.text = widget.recipe!.instructions;
      _prepTimeController.text = '${widget.recipe!.prepTime}';
      _selectedCategoryId = widget.recipe!.categoryId;
      if (widget.recipe!.ingredients != null && widget.recipe!.ingredients!.isNotEmpty) {
        _ingredients = widget.recipe!.ingredients!.map((i) => {
          'name': i.name,
          'quantity': i.quantity.toInt() == i.quantity ? i.quantity.toInt().toString() : i.quantity.toString(),
          'unit': i.unit,
        }).toList();
      }
    }
    if (_ingredients.isEmpty) {
      _ingredients.add({'name': '', 'quantity': '1', 'unit': ''});
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _prepTimeController.dispose();
    super.dispose();
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
        _selectedCategoryId ??= list.isNotEmpty ? list.first.id : null;
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

  String? _validateTitle(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Title is required';
    if (s.length > 255) return 'Title too long';
    return null;
  }

  String? _validateInstructions(String? v) {
    if ((v?.trim() ?? '').isEmpty) return 'Instructions are required';
    return null;
  }

  String? _validatePrepTime(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null || n < 1) return 'Enter a valid prep time (minutes)';
    return null;
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked != null && mounted) setState(() => _pickedImage = picked);
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: Theme.of(context).colorScheme.secondary),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _submit() async {
    _submitError = null;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      setState(() => _submitError =
          _categories.isEmpty ? 'No categories available.' : 'Please select a category');
      return;
    }
    final title = _titleController.text.trim();
    final instructions = _instructionsController.text.trim();
    final prepTime = int.tryParse(_prepTimeController.text.trim()) ?? 0;
    final ingredients = _ingredients
        .where((i) => (i['name'] ?? '').trim().isNotEmpty)
        .map((i) => {
              'name': (i['name'] ?? '').trim(),
              'quantity': double.tryParse((i['quantity'] ?? '1').trim()) ?? 1,
              'unit': (i['unit'] ?? '').trim().isEmpty ? 'unit' : (i['unit'] ?? '').trim(),
            })
        .toList();
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await RecipeService.instance.updateRecipe(
          widget.recipe!.id,
          categoryId: _selectedCategoryId!,
          title: title,
          instructions: instructions,
          prepTime: prepTime,
          ingredients: ingredients,
        );
        if (_pickedImage != null) {
          await RecipeService.instance.uploadRecipeImage(widget.recipe!.id, _pickedImage!);
        }
      } else {
        final recipeId = await RecipeService.instance.createRecipe(
          categoryId: _selectedCategoryId!,
          title: title,
          instructions: instructions,
          prepTime: prepTime,
          ingredients: ingredients,
        );
        if (_pickedImage != null) {
          await RecipeService.instance.uploadRecipeImage(recipeId, _pickedImage!);
        }
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

  Widget _buildIngredientsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_ingredients.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _ingredients[i]['name'],
                    decoration: const InputDecoration(
                      hintText: 'e.g. Flour',
                      isDense: true,
                    ),
                    onChanged: (v) => _ingredients[i]['name'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: TextFormField(
                    initialValue: _ingredients[i]['quantity'],
                    decoration: const InputDecoration(
                      hintText: 'Qty',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _ingredients[i]['quantity'] = v,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextFormField(
                    initialValue: _ingredients[i]['unit'],
                    decoration: const InputDecoration(
                      hintText: 'e.g. cup',
                      isDense: true,
                    ),
                    onChanged: (v) => _ingredients[i]['unit'] = v,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: colorScheme.secondary, size: 22),
                  onPressed: _ingredients.length > 1
                      ? () => setState(() => _ingredients.removeAt(i))
                      : null,
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => setState(() => _ingredients.add({'name': '', 'quantity': '1', 'unit': ''})),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Add ingredient'),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipe photo',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        if (_pickedImage != null) ...[
          FutureBuilder<dynamic>(
            future: _pickedImage!.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: Image.memory(
                        snapshot.data! as Uint8List,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () => setState(() => _pickedImage = null),
                    ),
                  ],
                );
              }
              return SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _pickingImage ? null : _pickImage,
          icon: _pickingImage
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: colorScheme.primary, strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_pickedImage == null ? 'Add photo' : 'Change photo'),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    final colorScheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loadError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_loadError!, style: TextStyle(color: colorScheme.secondary)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadCategories,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_submitError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Text(_submitError!, style: TextStyle(color: colorScheme.secondary)),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<int>(
            initialValue: _categories.isEmpty ? null : _selectedCategoryId,
            decoration: const InputDecoration(labelText: 'Category'),
            hint: Text(_categories.isEmpty ? 'No categories yet' : 'Select a category'),
            items: _categories
                .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                .toList(),
            onChanged: _categories.isEmpty ? null : (v) => setState(() => _selectedCategoryId = v),
            validator: (v) => v == null ? 'Select a category' : null,
          ),
          const SizedBox(height: 16),
          _buildImageSection(),
          const SizedBox(height: 16),
          _buildIngredientsSection(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: _validateTitle,
            maxLength: 255,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _instructionsController,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              alignLabelWithHint: true,
            ),
            validator: _validateInstructions,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prepTimeController,
            decoration: const InputDecoration(labelText: 'Prep time (minutes)'),
            keyboardType: TextInputType.number,
            validator: _validatePrepTime,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Update Recipe' : 'Create Recipe'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.asModal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Recipe' : 'New Recipe',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _loadingCategories
                ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildFormContent(),
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Recipe' : 'New Recipe',
          style: theme.textTheme.titleLarge,
        ),
      ),
      body: _loadingCategories
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildFormContent(),
            ),
    );
  }
}
