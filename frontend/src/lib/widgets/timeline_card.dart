import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:my_app/models/post.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/widgets/initials_avatar.dart';

/// Timeline Card widget for the feed.
/// Displays a post in a modern card format with relative time.
class TimelineCard extends StatelessWidget {
  final Post post;
  final bool isLiked;
  final int likesCount;
  final int commentsCount;
  final VoidCallback? onTap;
  final VoidCallback? onUserTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onRecipeTap;

  const TimelineCard({
    super.key,
    required this.post,
    this.isLiked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.onTap,
    this.onUserTap,
    this.onLikeTap,
    this.onCommentTap,
    this.onRecipeTap,
  });

  String _formatTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    try {
      final date = DateTime.parse(createdAt);
      return timeago.format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: User info + time
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // User avatar
                  GestureDetector(
                    onTap: onUserTap,
                    child: post.displayAuthorProfilePhotoUrl != null
                        ? CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                              post.displayAuthorProfilePhotoUrl!,
                            ),
                          )
                        : InitialsAvatar(
                            name: post.userName,
                            size: 40,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // User name and time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: onUserTap,
                          child: Text(
                            post.userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: kBodyTextDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(post.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: kCaptionGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recipe badge if this is a recipe post
                  if (post.recipeId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.restaurant_menu,
                            size: 14,
                            color: kPrimaryGreen,
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: onRecipeTap,
                            child: const Text(
                              'Recipe',
                              style: TextStyle(
                                fontSize: 12,
                                color: kPrimaryGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Content
            if (post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(
                  post.content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kBodyTextDark,
                    height: 1.4,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            
            // Image
            if (post.displayImageUrl != null && post.displayImageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: ClipRRect(
                  child: Image.network(
                    post.displayImageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            
            // Actions: Like and Comment
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Like button
                  _ActionButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    iconColor: isLiked ? Colors.red : kCaptionGray,
                    label: likesCount.toString(),
                    onTap: onLikeTap,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // Comment button
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    iconColor: kCaptionGray,
                    label: commentsCount.toString(),
                    onTap: onCommentTap,
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: iconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}