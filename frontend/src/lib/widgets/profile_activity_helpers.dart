import 'package:my_app/models/post.dart';
import 'package:my_app/models/recipe.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Rows for the profile "Liked" tab (heart on recipe or post).
class LikedActivityRow {
  final Recipe? recipe;
  final Post? post;

  const LikedActivityRow.recipe(this.recipe) : post = null;
  const LikedActivityRow.post(this.post) : recipe = null;

  bool get isRecipe => recipe != null;
}

DateTime? _parseCreatedAt(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    return DateTime.parse(iso);
  } catch (_) {
    return null;
  }
}

/// Merges liked recipes and liked posts by [created_at] descending.
List<LikedActivityRow> mergeLikedActivityRows(
  List<Recipe> recipes,
  List<Post> posts,
) {
  final entries = <({DateTime? t, LikedActivityRow row})>[];
  for (final r in recipes) {
    entries.add((
      t: _parseCreatedAt(r.createdAt),
      row: LikedActivityRow.recipe(r),
    ));
  }
  for (final p in posts) {
    entries.add((
      t: _parseCreatedAt(p.createdAt),
      row: LikedActivityRow.post(p),
    ));
  }
  entries.sort((a, b) {
    final da = a.t ?? DateTime.fromMillisecondsSinceEpoch(0);
    final db = b.t ?? DateTime.fromMillisecondsSinceEpoch(0);
    return db.compareTo(da);
  });
  return entries.map((e) => e.row).toList();
}

String formatProfilePostedAt(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    return timeago.format(DateTime.parse(iso));
  } catch (_) {
    return '';
  }
}

String postPreviewTitle(Post post) {
  final t = post.title?.trim();
  if (t != null && t.isNotEmpty) return t;
  final c = post.content.trim();
  if (c.isEmpty) return 'Post';
  return c.length > 72 ? '${c.substring(0, 72)}…' : c;
}

String? recipePreviewImageUrl(Recipe recipe) {
  final main = recipe.displayImageUrl;
  if (main != null && main.isNotEmpty) return main;
  final gallery = recipe.galleryDisplayUrls;
  if (gallery.isNotEmpty) return gallery.first;
  return null;
}
