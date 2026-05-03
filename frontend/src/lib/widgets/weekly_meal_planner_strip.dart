import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:my_app/models/meal_plan.dart';
import 'package:my_app/models/recipe.dart';
import 'package:my_app/services/meal_plan_service.dart';
import 'package:my_app/services/saved_recipe_service.dart';
import 'package:my_app/theme/app_theme.dart';

class WeeklyMealPlannerStrip extends StatefulWidget {
  final DateTime weekStart;
  final void Function(DateTime nextWeekStart) onWeekChanged;
  final Map<DateTime, int?>? selections;
  final List<Recipe>? recipes;
  final void Function(DateTime day, int? recipeId)? onAssignRecipe;

  const WeeklyMealPlannerStrip({
    super.key,
    required this.weekStart,
    required this.onWeekChanged,
    this.selections,
    this.recipes,
    this.onAssignRecipe,
  });

  @override
  State<WeeklyMealPlannerStrip> createState() => _WeeklyMealPlannerStripState();
}

class _WeeklyMealPlannerStripState extends State<WeeklyMealPlannerStrip> {
  List<MealPlan> _plans = [];
  bool _loading = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void didUpdateWidget(covariant WeeklyMealPlannerStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) {
      _loadPlans();
    }
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final plans = await MealPlanService.instance.fetchForWeek(widget.weekStart);
      if (mounted) setState(() { _plans = plans; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  MealPlan? _planForDay(DateTime day) {
    final d = _normalized(day);
    return _plans.cast<MealPlan?>().firstWhere(
      (p) => p != null && _normalized(p.plannedDate) == d,
      orElse: () => null,
    );
  }

  Future<void> _assignRecipe(DateTime day) async {
    final picked = await _showSavedRecipePicker(context, day);
    if (picked == null) return;
    try {
      final plan = await MealPlanService.instance.create(
        recipeId: picked.id,
        plannedDate: _normalized(day),
      );
      if (mounted) {
        setState(() {
        _plans.removeWhere((p) => _normalized(p.plannedDate) == _normalized(day));
        _plans.add(plan);
      });
      }
      widget.onAssignRecipe?.call(_normalized(day), picked.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _removePlan(MealPlan plan) async {
    final removed = plan;
    setState(() => _plans.removeWhere((p) => p.id == plan.id));
    try {
      await MealPlanService.instance.delete(plan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meal removed'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  final restored = await MealPlanService.instance.create(
                    recipeId: removed.recipeId,
                    plannedDate: removed.plannedDate,
                    mealSlot: removed.mealSlot,
                  );
                  if (mounted) setState(() => _plans.add(restored));
                } catch (_) {}
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _plans.add(removed));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  // ── PDF export ────────────────────────────────────────────────────────────

  Future<void> _exportToPdf() async {
    setState(() => _exporting = true);
    try {
      final exportData = await MealPlanService.instance.fetchExportData(widget.weekStart);
      final pdfBytes = await _generatePdf(exportData);
      await _savePdf(pdfBytes, exportData.weekStart);
      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meal plan saved to Downloads'),
            backgroundColor: colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _generatePdf(MealPlanExport data) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'WellNest — Weekly Meal Plan',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                '${data.weekStart}  to  ${data.weekEnd}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.Text(
                'Prepared for ${data.userName}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 20),
              if (data.meals.isEmpty)
                pw.Text('No meals planned for this week.', style: const pw.TextStyle(fontSize: 14))
              else
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                  cellStyle: const pw.TextStyle(fontSize: 11),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.green50),
                  cellHeight: 30,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(4),
                    3: const pw.FlexColumnWidth(2),
                  },
                  headers: ['Day', 'Date', 'Recipe', 'Prep Time'],
                  data: data.meals.map((m) => [
                    m.day,
                    m.date,
                    m.recipeTitle,
                    m.prepTime != null ? '${m.prepTime} min' : '—',
                  ]).toList(),
                ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  Future<void> _savePdf(Uint8List bytes, String weekStart) async {
    final fileName = 'meal-plan-$weekStart.pdf';

    if (kIsWeb) {
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
      );
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)]);
  }

  // ── Saved recipe picker ────────────────────────────────────────────────────

  Future<Recipe?> _showSavedRecipePicker(BuildContext context, DateTime day) async {
    return showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedRecipePickerSheet(day: day),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = List.generate(
      7,
      (i) => DateTime(widget.weekStart.year, widget.weekStart.month, widget.weekStart.day + i),
    );
    final planned = _plans.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: isDark
            ? Border.all(color: colorScheme.outlineVariant.withOpacity(0.5))
            : null,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branded header bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(isDark ? 0.15 : 0.06),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 22, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Meal Planner',
                        style: TextStyle(
                          fontFamily: kFontAppFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$planned of 7 days planned',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_exporting)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Export week to PDF',
                    onPressed: _plans.isEmpty ? null : _exportToPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
          // Week navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => widget.onWeekChanged(
                    widget.weekStart.subtract(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_left, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _rangeLabel(weekDays.first, weekDays.last),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => widget.onWeekChanged(
                    widget.weekStart.add(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_right, size: 22),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Day cells
          SizedBox(
            height: 155,
            child: _loading
                ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: weekDays.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final day = weekDays[index];
                        final plan = _planForDay(day);
                        return _buildDayCell(context, day, plan);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime day, MealPlan? plan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isToday = _normalized(day) == _normalized(DateTime.now());
    final hasRecipe = plan != null;

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasRecipe
            ? () => _showDayOptions(context, day, plan)
            : () => _assignRecipe(day),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: hasRecipe
                ? colorScheme.primary.withOpacity(isDark ? 0.18 : 0.08)
                : (isDark
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.6)
                    : colorScheme.surfaceContainerHighest.withOpacity(0.45)),
            border: Border.all(
              color: isToday
                  ? colorScheme.primary
                  : (hasRecipe
                      ? colorScheme.primary.withOpacity(0.25)
                      : colorScheme.outlineVariant.withOpacity(isDark ? 0.4 : 0.3)),
              width: isToday ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day name + date row
              Row(
                children: [
                  Text(
                    _dayLabel(day),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isToday ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday
                          ? colorScheme.primary
                          : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Content area
              if (hasRecipe) ...[
                Row(
                  children: [
                    Icon(Icons.restaurant_rounded, size: 13, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        plan.recipe?.title ?? 'Planned',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                if (plan.recipe != null && plan.recipe!.prepTime > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${plan.recipe!.prepTime} min',
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 22,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plan meal',
                        style: TextStyle(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!hasRecipe) return card;

    return Dismissible(
      key: ValueKey(plan.id),
      direction: DismissDirection.up,
      background: Container(
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 6),
        child: Icon(Icons.delete_outline, color: colorScheme.error, size: 20),
      ),
      onDismissed: (_) => _removePlan(plan),
      child: card,
    );
  }

  void _showDayOptions(BuildContext context, DateTime day, MealPlan plan) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.swap_horiz, color: colorScheme.primary),
                title: const Text('Change recipe'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assignRecipe(day);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: const Text('Remove meal'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removePlan(plan);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime _normalized(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dayLabel(DateTime day) {
    const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return labels[day.weekday - 1];
  }

  static String _rangeLabel(DateTime start, DateTime end) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final sm = months[start.month - 1];
    final em = months[end.month - 1];
    if (start.month == end.month) {
      return '$sm ${start.day} – ${end.day}';
    }
    return '$sm ${start.day} – $em ${end.day}';
  }
}

// ── Saved recipe picker bottom sheet ─────────────────────────────────────────

class _SavedRecipePickerSheet extends StatefulWidget {
  final DateTime day;

  const _SavedRecipePickerSheet({required this.day});

  @override
  State<_SavedRecipePickerSheet> createState() => _SavedRecipePickerSheetState();
}

class _SavedRecipePickerSheetState extends State<_SavedRecipePickerSheet> {
  List<Recipe> _recipes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SavedRecipeService.instance.fetchSavedRecipes();
      if (mounted) setState(() { _recipes = data.recipes; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dayName = _dayNames[widget.day.weekday - 1];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu, size: 22, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan for $dayName',
                        style: TextStyle(
                          fontFamily: kFontAppFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pick from your saved recipes',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: _loading
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ))
                : _error != null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ))
                    : _recipes.isEmpty
                        ? Center(child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bookmark_border,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No saved recipes yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Save recipes from Discover to plan meals.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _recipes.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                            itemBuilder: (context, index) {
                              final recipe = _recipes[index];
                              final isDark = theme.brightness == Brightness.dark;
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 48, height: 48,
                                    child: recipe.displayImageUrl != null
                                        ? Image.network(
                                            recipe.displayImageUrl!,
                                            fit: BoxFit.cover,
                                            cacheWidth: 96,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: isDark
                                                  ? colorScheme.surfaceContainerHighest
                                                  : kImagePlaceholderGreen,
                                              child: Icon(Icons.restaurant, size: 20, color: colorScheme.onSurfaceVariant),
                                            ),
                                          )
                                        : Container(
                                            color: isDark
                                                ? colorScheme.surfaceContainerHighest
                                                : kImagePlaceholderGreen,
                                            child: Icon(Icons.restaurant, size: 20, color: colorScheme.onSurfaceVariant),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  recipe.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  '${recipe.prepTime} min',
                                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                                ),
                                trailing: Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 22),
                                onTap: () => Navigator.pop(context, recipe),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
