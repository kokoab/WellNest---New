/// User returned from GET /api/users/search (for starting a chat).
class UserSearchResult {
  final int id;
  final String name;

  UserSearchResult({required this.id, required this.name});

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
    );
  }
}
