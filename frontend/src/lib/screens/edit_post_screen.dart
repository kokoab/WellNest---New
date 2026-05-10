import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/post.dart';
import 'package:my_app/services/api_service.dart';
import 'package:my_app/services/post_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';

/// One gallery slot while editing — either an existing server image or a new local file.
class _EditImgSlot {
  _EditImgSlot.server(PostGalleryImage s)
      : server = s,
        local = null;
  _EditImgSlot.local(XFile f)
      : local = f,
        server = null;

  final PostGalleryImage? server;
  final XFile? local;
}

/// Edit post — compact text composer and photos below.
class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});

  final Post post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  static const int _kMaxPostImages = 10;

  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _controller;
  late List<_EditImgSlot> _slots;

  bool _saving = false;
  bool _pickingImages = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.post.content);
    _slots = widget.post.galleryImages
        .map((g) => _EditImgSlot.server(g))
        .toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _remainingSlots => _kMaxPostImages - _slots.length;

  Future<void> _pickImages() async {
    final remain = _remainingSlots;
    if (remain <= 0 || _pickingImages || _saving) return;
    setState(() => _pickingImages = true);
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (!mounted) return;
      setState(() {
        for (final f in picked.take(remain)) {
          _slots.add(_EditImgSlot.local(f));
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick images: $e'),
            backgroundColor: kAccentOrange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingImages = false);
    }
  }

  Future<void> _removeSlot(int index) async {
    final slot = _slots[index];
    if (slot.server != null) {
      try {
        await _apiService.deletePostImage(
          widget.post.id,
          slot.server!.id,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: kAccentOrange,
            ),
          );
        }
        return;
      }
    }
    setState(() => _slots.removeAt(index));
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await PostService.instance.updatePost(
        widget.post.id,
        content: text,
      );

      final ids = <int>[];
      for (final slot in _slots) {
        if (slot.server != null) {
          ids.add(slot.server!.id);
        } else if (slot.local != null) {
          final id = await _apiService.uploadPostImage(
            widget.post.id,
            slot.local!,
          );
          ids.add(id);
        }
      }
      if (ids.length > 1) {
        await _apiService.reorderPostImages(widget.post.id, ids);
      }

      final fresh = await PostService.instance.fetchPost(widget.post.id);
      if (mounted) Navigator.of(context).pop<Post>(fresh);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: kAccentOrange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = wellnestOutlineColor(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(
          'Edit post',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: kPrimaryGreen,
            fontFamily: kFontHelveticaNow,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kPrimaryGreen,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kPrimaryGreen,
                      fontFamily: kFontHelveticaNow,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: outline),
                ),
                // Tight around content; extra bottom ≈ one text line (17 × 1.45).
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  12,
                  AppSpacing.md,
                  36,
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !_saving,
                  maxLines: null,
                  minLines: 1,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: kFontHelveticaNow,
                    fontSize: 17,
                    height: 1.45,
                    color: kBodyTextDark,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(
                      color: kPrimaryGreen.withValues(alpha: 0.42),
                      fontFamily: kFontHelveticaNow,
                      fontSize: 17,
                      height: 1.45,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Photos',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: kPrimaryGreen,
                  fontFamily: kFontHelveticaNow,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'First photo is the cover in the feed. Up to $_kMaxPostImages images.',
                style: TextStyle(
                  fontFamily: kFontHelveticaNow,
                  fontSize: 13,
                  color: kCaptionGray,
                  height: 1.35,
                ),
              ),
              if (widget.post.galleryImages.isEmpty &&
                  widget.post.galleryDisplayUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm2),
                  decoration: BoxDecoration(
                    color: kPrimaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kPrimaryGreen.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: kPrimaryGreen,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This post still has a legacy cover image in the feed. '
                          'Add photos here to manage a full gallery and cover.',
                          style: TextStyle(
                            fontFamily: kFontHelveticaNow,
                            fontSize: 13,
                            height: 1.35,
                            color: kBodyTextDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm2),
              OutlinedButton.icon(
                onPressed:
                    (_saving || _pickingImages || _remainingSlots <= 0)
                        ? null
                        : _pickImages,
                icon: _pickingImages
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kPrimaryGreen,
                        ),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  _remainingSlots <= 0
                      ? 'Maximum photos reached'
                      : 'Add photos',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryGreen,
                  side: BorderSide(color: outline),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                ),
              ),
              if (_slots.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                ...List.generate(_slots.length, (index) {
                  final slot = _slots[index];
                  return Padding(
                    key: ValueKey(
                      slot.server != null
                          ? 's-${slot.server!.id}'
                          : 'l-${slot.local!.path}-$index',
                    ),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: slot.server != null
                              ? Image.network(
                                  slot.server!.displayUrl ?? '',
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    height: 160,
                                    color: AppColors.imagePlaceholderGreen,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(slot.local!.path),
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    height: 160,
                                    color: AppColors.imagePlaceholderGreen,
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _saving
                                  ? null
                                  : () => _removeSlot(index),
                            ),
                          ),
                        ),
                        if (index == 0)
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
