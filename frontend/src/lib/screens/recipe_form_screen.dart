import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/category.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/services/category_service.dart';
import 'package:my_app/services/recipe_service.dart';

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
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: RecipeFormScreen(recipe: recipe, asModal: true),
        ),
      ),
    );
  }

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
  XFile? _pickedImage;
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
          SnackBar(content: Text('Could not pick image: $e'), backgroundColor: nestOrange),
        );
      }
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
        if (_pickedImage != null) {
          await RecipeService.instance.uploadRecipeImage(widget.recipe!.id, _pickedImage!);
        }
      } else {
        final recipeId = await RecipeService.instance.createRecipe(
          categoryId: _selectedCategoryId!,
          title: title,
          instructions: instructions,
          prepTime: prepTime,
        );
        if (_pickedImage != null) {
          await RecipeService.instance.uploadRecipeImage(recipeId, _pickedImage!);
        }
      }
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Recipe updated' : 'Recipe created'),
          backgroundColor: wellGreen,
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

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipe photo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
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
                      borderRadius: BorderRadius.circular(12),
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
              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
            },
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_pickedImage == null ? 'Add photo' : 'Change photo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: wellGreen,
            side: const BorderSide(color: wellGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
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
                  Text(_loadError!, style: const TextStyle(color: nestOrange)),
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
              child: Text(_submitError!, style: const TextStyle(color: nestOrange)),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<int>(
            value: _categories.isEmpty ? null : _selectedCategoryId,
            decoration: InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
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
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: _validateTitle,
            maxLength: 255,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _instructionsController,
            decoration: InputDecoration(
              labelText: 'Instructions',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: _validateInstructions,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _prepTimeController,
            decoration: InputDecoration(
              labelText: 'Prep time (minutes)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
    if (widget.asModal) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Recipe' : 'New Recipe',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _loadingCategories
                ? const Center(child: CircularProgressIndicator(color: wellGreen))
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
              child: _buildFormContent(),
            ),
    );
  }
}
