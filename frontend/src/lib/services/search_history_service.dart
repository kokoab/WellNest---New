import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum SearchHistoryArea { feed, savedRecipes }

/// Persists recent search strings per area (feed vs saved recipes).
class SearchHistoryService {
  SearchHistoryService._();
  static final SearchHistoryService instance = SearchHistoryService._();

  static const _feedKey = 'wellnest_search_history_feed_v1';
  static const _savedKey = 'wellnest_search_history_saved_v1';
  static const int _maxItems = 12;

  Future<List<String>> recent(SearchHistoryArea area) async {
    final prefs = await SharedPreferences.getInstance();
    final key = area == SearchHistoryArea.feed ? _feedKey : _savedKey;
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> record(SearchHistoryArea area, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = area == SearchHistoryArea.feed ? _feedKey : _savedKey;
    var existing = await recent(area);
    existing.removeWhere((s) => s.toLowerCase() == q.toLowerCase());
    existing.insert(0, q);
    if (existing.length > _maxItems) {
      existing = existing.sublist(0, _maxItems);
    }
    await prefs.setString(key, jsonEncode(existing));
  }

  Future<void> remove(SearchHistoryArea area, String query) async {
    final prefs = await SharedPreferences.getInstance();
    final key = area == SearchHistoryArea.feed ? _feedKey : _savedKey;
    final existing =
        (await recent(area))
            .where((s) => s.toLowerCase() != query.toLowerCase())
            .toList();
    await prefs.setString(key, jsonEncode(existing));
  }
}
