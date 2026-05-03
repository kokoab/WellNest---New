import 'package:flutter/material.dart';
import 'package:my_app/models/recipe_ranking_item.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/services/recipe_service.dart';
import 'package:my_app/theme/app_theme.dart';

class RecipeRankingScreen extends StatefulWidget {
  const RecipeRankingScreen({super.key});

  @override
  State<RecipeRankingScreen> createState() => _RecipeRankingScreenState();
}

class _RecipeRankingScreenState extends State<RecipeRankingScreen> {
  static const Color wellGreen = Color(0xFF097333);

  String _window = '7d';
  String _mode = 'combined';
  bool _loading = true;
  String? _error;
  List<RecipeRankingItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await RecipeService.instance.fetchRecipeRankings(
        window: _window,
        mode: _mode,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recipe Rankings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: wellGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _window,
                    decoration: const InputDecoration(labelText: 'Window'),
                    items: const [
                      DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                      DropdownMenuItem(
                        value: '30d',
                        child: Text('Last 30 days'),
                      ),
                      DropdownMenuItem(value: 'all', child: Text('All time')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _window = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mode,
                    decoration: const InputDecoration(labelText: 'Sort by'),
                    items: const [
                      DropdownMenuItem(
                        value: 'combined',
                        child: Text('Combined'),
                      ),
                      DropdownMenuItem(value: 'views', child: Text('Views')),
                      DropdownMenuItem(
                        value: 'ratings',
                        child: Text('Ratings'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _mode = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: wellGreen),
                  )
                : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                ? const Center(child: Text('No ranking data yet.'))
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0x1A097333),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: kPrimaryGreen),
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '⭐ ${item.averageRating.toStringAsFixed(1)} (${item.ratingsCount})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item.viewsCount}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          'Score ${item.score.toStringAsFixed(2)}',
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) =>
                                RecipeDetailScreen(recipeId: item.id),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
