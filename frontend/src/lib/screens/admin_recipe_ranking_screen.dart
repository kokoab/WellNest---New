import 'package:flutter/material.dart';
import 'package:my_app/models/recipe_ranking_item.dart';
import 'package:my_app/services/recipe_service.dart';

class AdminRecipeRankingScreen extends StatefulWidget {
  const AdminRecipeRankingScreen({super.key});

  @override
  State<AdminRecipeRankingScreen> createState() =>
      _AdminRecipeRankingScreenState();
}

class _AdminRecipeRankingScreenState extends State<AdminRecipeRankingScreen> {
  List<RecipeRankingItem> _rows = [];
  bool _loading = true;
  String? _error;
  String _window = '7d';
  int _sortIndex = 0;
  bool _ascending = false;

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
      final rows = await RecipeService.instance.fetchRankings(
        window: _window,
        mode: 'combined',
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _sort<T>(int column, T Function(RecipeRankingItem r) key) {
    setState(() {
      if (_sortIndex == column) {
        _ascending = !_ascending;
      } else {
        _sortIndex = column;
        _ascending = false;
      }
      _rows.sort((a, b) {
        final av = key(a);
        final bv = key(b);
        final cmp = Comparable.compare(av as Comparable, bv as Comparable);
        return _ascending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: _window,
            items: const [
              DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
              DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
              DropdownMenuItem(value: 'all', child: Text('All time')),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _window = v);
              _load();
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              sortColumnIndex: _sortIndex,
              sortAscending: _ascending,
              columns: [
                const DataColumn(label: Text('Rank')),
                DataColumn(
                  label: const Text('Title'),
                  onSort: (_, __) => _sort(1, (r) => r.title),
                ),
                DataColumn(
                  label: const Text('Views'),
                  numeric: true,
                  onSort: (_, __) => _sort(2, (r) => r.viewsCount),
                ),
                DataColumn(
                  label: const Text('Avg Rating'),
                  numeric: true,
                  onSort: (_, __) => _sort(3, (r) => r.averageRating),
                ),
                DataColumn(
                  label: const Text('Ratings'),
                  numeric: true,
                  onSort: (_, __) => _sort(4, (r) => r.ratingsCount),
                ),
                DataColumn(
                  label: const Text('Score'),
                  numeric: true,
                  onSort: (_, __) => _sort(5, (r) => r.score),
                ),
              ],
              rows: List.generate(_rows.length, (i) {
                final r = _rows[i];
                return DataRow(
                  cells: [
                    DataCell(Text('${i + 1}')),
                    DataCell(Text(r.title)),
                    DataCell(Text('${r.viewsCount}')),
                    DataCell(Text(r.averageRating.toStringAsFixed(2))),
                    DataCell(Text('${r.ratingsCount}')),
                    DataCell(Text(r.score.toStringAsFixed(3))),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
