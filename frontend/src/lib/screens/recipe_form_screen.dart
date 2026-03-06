import 'package:flutter/material.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/services/category_service.dart';
import 'package:my_app/services/recipe_service.dart';

class RecipeFormScreen extends StatefulWidget {
  final Recipe? recipe;

  const RecipeFormScreen({super.key, this.recipe});

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  static const Color wellGreen = Color(0xFF097333);
  static const Color nestOrange = Color(0xFFEF5026);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _prepTimeController = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _loadingCategories = true;
  bool _saving = false;
  String? _submitError;
  String? _loadError;

  bool get _isEditing => widget.recipe != null;

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      _titleController.text = widget.recipe!.title;
      _instructionsController.text = widget.recipe!.instructions;
      _prepTimeController.text = '${widget.recipe!.prepTime}';
      _selectedCategoryId = widget.recipe!.categoryId;
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
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await RecipeService.instance.updateRecipe(
          widget.recipe!.id,
          categoryId: _selectedCategoryId!,
          title: title,
          instructions: instructions,
          prepTime: prepTime,
        );
      } else {
        await RecipeService.instance.createRecipe(
          categoryId: _selectedCategoryId!,
          title: title,
          instructions: instructions,
          prepTime: prepTime,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Recipe updated' : 'Recipe created'),
          backgroundColor: wellGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Recipe' : 'New Recipe',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: wellGreen,
        foregroundColor: Colors.white,
      ),
      body: _loadingCategories
          ? const Center(child: CircularProgressIndicator(color: wellGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: nestOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loadError!,
                              style: const TextStyle(color: nestOrange),
                            ),
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
                          color: nestOrange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _submitError!,
                          style: const TextStyle(color: nestOrange),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    DropdownButtonFormField<int>(
                      value: _categories.isEmpty ? null : _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      hint: Text(_categories.isEmpty ? 'No categories yet' : 'Select a category'),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: _categories.isEmpty ? null : (v) => setState(() => _selectedCategoryId = v),
                      validator: (v) => v == null ? 'Select a category' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateTitle,
                      maxLength: 255,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Instructions',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: _validateInstructions,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _prepTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Prep time (minutes)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: _validatePrepTime,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: wellGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_isEditing ? 'Update Recipe' : 'Create Recipe'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
