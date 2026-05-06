import 'package:flutter/material.dart';

/// A generic mixin or helper to handle infinite scroll logic in Flutter.
mixin PaginationMixin<T> {
  List<T> items = [];
  int currentPage = 1;
  bool isLoading = false;
  bool hasMore = true;
  final ScrollController scrollController = ScrollController();

  void initPagination(Future<void> Function() fetchFunction) {
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        if (!isLoading && hasMore) {
          fetchFunction();
        }
      }
    });
  }

  void disposePagination() {
    scrollController.dispose();
  }

  /// Call this inside your API service logic
  void handleResponse(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    final List rawData = json['data'] ?? [];
    final List<T> newItems = rawData.map((item) => fromJson(item)).toList();
    
    if (currentPage == 1) {
      items = newItems;
    } else {
      items.addAll(newItems);
    }

    // Laravel's length-aware paginator provides 'next_page_url'
    hasMore = json['next_page_url'] != null;
    if (hasMore) {
      currentPage++;
    }
  }
}

/* 
Example usage in a StatefulWidget:

class RecipeListScreen extends StatefulWidget { ... }
class _RecipeListScreenState extends State<RecipeListScreen> with PaginationMixin<Recipe> {
  @override
  void initState() {
    super.initState();
    initPagination(fetchRecipes);
    fetchRecipes();
  }

  Future<void> fetchRecipes() async {
    setState(() => isLoading = true);
    final response = await api.get('/recipes?page=$currentPage');
    setState(() {
      handleResponse(response.data, (json) => Recipe.fromJson(json));
      isLoading = false;
    });
  }
}
*/