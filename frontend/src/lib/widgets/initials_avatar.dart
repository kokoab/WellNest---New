import 'package:flutter/material.dart';
import 'package:my_app/theme/app_theme.dart';

/// Format ISO8601 [createdAt] as "X min ago" / "X hours ago" / short date.
String formatPostTime(String? createdAt) {
  if (createdAt == null || createdAt.isEmpty) return '';
  final t = DateTime.tryParse(createdAt);
  if (t == null) return '';
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${t.month}/${t.day}/${t.year}';
}

/// Circle avatar with initials in the app style: pale cream background, bold dark green text.
/// When [imageUrl] is set (resolved display URL), shows a cropped photo with [BoxFit.cover] (no stretch).
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.imageUrl,
  });

  static String getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length == 1) {
      final s = parts[0];
      return s.length >= 2 ? s.substring(0, 2).toUpperCase() : s.toUpperCase();
    }
    return ((parts[0].isNotEmpty ? parts[0][0] : '') + (parts[1].isNotEmpty ? parts[1][0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = getInitials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFEECC),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.trim().isNotEmpty
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * 2).toInt(),
                cacheHeight: (size * 2).toInt(),
                errorBuilder: (_, __, ___) => _buildInitials(initials),
              )
            : _buildInitials(initials),
      ),
    );
  }

  Widget _buildInitials(String initials) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
