/// Cuisine chip shown in the Discover search panel (from rankings data).
class PopularCuisineItem {
  final String label;
  final String? imageUrl;
  final String searchTerm;

  const PopularCuisineItem({
    required this.label,
    required this.imageUrl,
    required this.searchTerm,
  });
}
