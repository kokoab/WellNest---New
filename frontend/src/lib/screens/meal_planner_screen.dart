import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'package:my_app/app_route_observer.dart';
import 'package:my_app/models/meal_plan.dart';
import 'package:my_app/screens/notifications_screen.dart';
import 'package:my_app/screens/recipe_detail_screen.dart';
import 'package:my_app/services/meal_plan_service.dart';
import 'package:my_app/theme/app_spacing.dart';
import 'package:my_app/theme/app_theme.dart';
import 'package:my_app/utils/meal_plan_week_utils.dart';
import 'package:my_app/utils/recipe_image_url.dart';
import 'package:my_app/widgets/meal_plan_pdf_export.dart';
import 'package:my_app/widgets/meal_plan_recipe_picker_sheet.dart';

/// Full-screen weekly planner: one week strip, day pager, breakfast/lunch/dinner slots.
class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealSlotDef {
  final String key;
  final String label;
  const _MealSlotDef(this.key, this.label);
}

class _MealPlannerScreenState extends State<MealPlannerScreen> with RouteAware {
  static const List<_MealSlotDef> _slots = [
    _MealSlotDef('breakfast', 'Breakfast'),
    _MealSlotDef('lunch', 'Lunch'),
    _MealSlotDef('dinner', 'Dinner'),
  ];

  List<MealPlan> _plans = [];
  Set<String> _skippedMealKeys = {};
  bool _loading = false;
  bool _exporting = false;
  late DateTime _weekStart;
  late PageController _pageController;
  int _dayPageIndex = 0;
  /// Next week animates in from the right; previous week from the left.
  bool _weekSlideForward = true;

  List<DateTime> get _weekDays => List.generate(
    7,
    (i) => DateTime(_weekStart.year, _weekStart.month, _weekStart.day + i),
  );

  @override
  void initState() {
    super.initState();
    _weekStart = MealPlanWeekUtils.startOfWeekMonday(DateTime.now());
    _dayPageIndex = MealPlanWeekUtils.initialDayPageIndex(_weekStart);
    _pageController = PageController(initialPage: _dayPageIndex);
    MealPlanService.changes.addListener(_onMealPlanChanged);
    _loadPlans();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    MealPlanService.changes.removeListener(_onMealPlanChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onMealPlanChanged() {
    if (!mounted) return;
    _loadPlans(silent: true);
  }

  @override
  void didPopNext() {
    _loadPlans(silent: true);
  }

  Future<void> _loadPlans({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final week = await MealPlanService.instance.fetchForWeek(_weekStart);
      if (!mounted) return;
      setState(() {
        _plans = week.plans;
        _skippedMealKeys = week.skippedMealKeys;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  MealPlan? _planFor(DateTime day, String slotKey) {
    final d = MealPlanWeekUtils.normalize(day);
    for (final p in _plans) {
      if (MealPlanWeekUtils.normalize(p.plannedDate) == d &&
          p.mealSlot == slotKey) {
        return p;
      }
    }
    return null;
  }

  bool _mealSkipped(DateTime day, String slotKey) {
    final key = MealPlanService.mealSkipKey(
      MealPlanWeekUtils.toIsoDate(day),
      slotKey,
    );
    return _skippedMealKeys.contains(key);
  }

  int _filledSlotCount(DateTime day) {
    var n = 0;
    for (final s in _slots) {
      if (_planFor(day, s.key) != null) n++;
    }
    return n;
  }

  int _partialDayCount() {
    var n = 0;
    for (final day in _weekDays) {
      final done = _completedSlotCount(day);
      if (done > 0 && done < _slots.length) n++;
    }
    return n;
  }

  int _skippedMealCountInWeek() {
    var n = 0;
    for (final day in _weekDays) {
      for (final s in _slots) {
        if (_mealSkipped(day, s.key)) n++;
      }
    }
    return n;
  }

  int _completedSlotCount(DateTime day) {
    var n = 0;
    for (final s in _slots) {
      if (_planFor(day, s.key) != null || _mealSkipped(day, s.key)) n++;
    }
    return n;
  }

  Future<void> _setMealSkipped(
    DateTime day,
    String slotKey,
    bool skipped,
  ) async {
    final d = MealPlanWeekUtils.normalize(day);
    final key = MealPlanService.mealSkipKey(
      MealPlanWeekUtils.toIsoDate(d),
      slotKey,
    );
    MealPlan? removedPlan;
    setState(() {
      if (skipped) {
        _skippedMealKeys = {..._skippedMealKeys, key};
        final nextPlans = <MealPlan>[];
        for (final p in _plans) {
          if (MealPlanWeekUtils.normalize(p.plannedDate) == d &&
              p.mealSlot == slotKey) {
            removedPlan = p;
          } else {
            nextPlans.add(p);
          }
        }
        _plans = nextPlans;
      } else {
        _skippedMealKeys = {..._skippedMealKeys}..remove(key);
      }
    });
    try {
      await MealPlanService.instance.setMealSkip(
        plannedDate: d,
        mealSlot: slotKey,
        skipped: skipped,
      );
      if (!mounted) return;
      await _loadPlans(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (skipped) {
          _skippedMealKeys = {..._skippedMealKeys}..remove(key);
          if (removedPlan != null) _plans = [..._plans, removedPlan!];
        } else {
          _skippedMealKeys = {..._skippedMealKeys, key};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  int _plannedSlotCountForWeek() {
    var n = 0;
    for (final day in _weekDays) {
      for (final s in _slots) {
        if (_planFor(day, s.key) != null || _mealSkipped(day, s.key)) n++;
      }
    }
    return n;
  }

  Future<void> _assignRecipe(DateTime day, String slotKey) async {
    final slotLabel = _slots
        .firstWhere((s) => s.key == slotKey, orElse: () => _slots.last)
        .label;
    final result = await showMealPlanRecipePicker(
      context,
      day: day,
      mealSlotKey: slotKey,
      mealSlotLabel: slotLabel,
    );
    if (result == null || !mounted) return;
    if (result.skipped) {
      await _setMealSkipped(day, slotKey, true);
      return;
    }
    final picked = result.recipe;
    if (picked == null) return;
    try {
      final created = await MealPlanService.instance.create(
        recipeId: picked.id,
        plannedDate: MealPlanWeekUtils.normalize(day),
        mealSlot: slotKey,
      );
      if (!mounted) return;
      final d = MealPlanWeekUtils.normalize(day);
      final key = MealPlanService.mealSkipKey(
        MealPlanWeekUtils.toIsoDate(d),
        slotKey,
      );
      setState(() {
        _skippedMealKeys = {..._skippedMealKeys}..remove(key);
        _plans = [
          for (final p in _plans)
            if (!(MealPlanWeekUtils.normalize(p.plannedDate) == d &&
                p.mealSlot == slotKey))
              p,
          created,
        ];
      });
      await _loadPlans(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _removePlan(MealPlan plan) async {
    final removed = plan;
    setState(() => _plans.removeWhere((p) => p.id == plan.id));
    try {
      await MealPlanService.instance.delete(plan.id);
      if (!mounted) return;
      await _loadPlans(silent: true);
      if (!mounted) return;
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
                if (mounted) {
                  setState(() => _plans.add(restored));
                  await _loadPlans(silent: true);
                }
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _plans.add(removed));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _showSlotOptions(DateTime day, MealPlan plan, String slotKey) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.visibility_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('View recipe'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RecipeDetailScreen(recipeId: plan.recipeId),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.swap_horiz, color: colorScheme.primary),
                title: const Text('Change recipe'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assignRecipe(day, slotKey);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.block_rounded,
                  color: colorScheme.secondary,
                ),
                title: const Text('Mark this meal as skipped'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setMealSkipped(day, slotKey, true);
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

  void _showSkippedSlotOptions(DateTime day, String slotKey, String slotLabel) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.add_circle_outline,
                  color: colorScheme.primary,
                ),
                title: Text('Add recipe for $slotLabel'),
                onTap: () {
                  Navigator.pop(ctx);
                  _assignRecipe(day, slotKey);
                },
              ),
              ListTile(
                leading: Icon(Icons.undo_rounded, color: colorScheme.secondary),
                title: const Text('Clear skipped meal'),
                onTap: () {
                  Navigator.pop(ctx);
                  _setMealSkipped(day, slotKey, false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_plans.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await MealPlanPdfExport.shareWeekPdf(_weekStart);
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Use the share dialog to save your PDF'
                : (defaultTargetPlatform == TargetPlatform.iOS ||
                          defaultTargetPlatform == TargetPlatform.android
                      ? 'Meal plan ready to share'
                      : 'Meal plan PDF generated'),
          ),
          backgroundColor: scheme.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _goWeek(int deltaDays) {
    final next = _weekStart.add(Duration(days: deltaDays));
    final idx = MealPlanWeekUtils.initialDayPageIndex(next);
    setState(() {
      _weekSlideForward = deltaDays > 0;
      _weekStart = next;
      _dayPageIndex = idx;
    });
    _pageController.jumpToPage(idx);
    _loadPlans();
  }

  void _onDayChipTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String? _weekDetailLine() {
    final p = _partialDayCount();
    final s = _skippedMealCountInWeek();
    if (p == 0 && s == 0) return null;
    final parts = <String>[];
    if (p > 0) {
      parts.add(p == 1 ? '1 day in progress' : '$p days in progress');
    }
    if (s > 0) {
      parts.add(
        s == 1 ? '1 meal marked as skipped' : '$s meals marked as skipped',
      );
    }
    return parts.join(' · ');
  }

  IconData _dayMarkerIcon(DateTime day) {
    final wd = day.weekday;
    if (wd == DateTime.saturday || wd == DateTime.sunday) {
      return Icons.weekend_outlined;
    }
    return Icons.event_note_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = _weekDays;
    final rangeLabel = MealPlanWeekUtils.rangeLabel(
      weekDays.first,
      weekDays.last,
    );
    final plannedSlots = _plannedSlotCountForWeek();
    final totalSlots = 7 * _slots.length;
    final weekDetail = _weekDetailLine();

    final outline = isDark
        ? colorScheme.outlineVariant.withValues(alpha: 0.5)
        : const Color(0xFFC5C5C5).withValues(alpha: 0.95);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Export week to PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _plans.isEmpty ? null : _exportPdf,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.32),
                          colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.88,
                          ),
                          colorScheme.primary.withValues(alpha: 0.14),
                        ],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          kHeroPaleGreen,
                          Color(0xFFFFFFFF),
                          Color(0xFFE8F5E9),
                        ],
                        stops: [0.0, 0.48, 1.0],
                      ),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                  color: outline.withValues(alpha: isDark ? 0.55 : 0.42),
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: kPrimaryGreen.withValues(alpha: 0.07),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 22,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weekly Meal Plan',
                                    style: TextStyle(
                                      fontFamily: kFontAppFamily,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$plannedSlots of $totalSlots slots filled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (weekDetail != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 200),
                                  child: Text(
                                    weekDetail,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.92),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _goWeek(-7),
                        icon: const Icon(Icons.chevron_left, size: 26),
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Text(
                          rangeLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _goWeek(7),
                        icon: const Icon(Icons.chevron_right, size: 26),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    ?currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );
                final begin = _weekSlideForward
                    ? const Offset(0.12, 0)
                    : const Offset(-0.12, 0);
                return SlideTransition(
                  position: Tween<Offset>(begin: begin, end: Offset.zero)
                      .animate(curved),
                  child: FadeTransition(
                    opacity: curved,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<String>(
                  '${_weekStart.year}-${_weekStart.month}-${_weekStart.day}',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: 7,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = weekDays[index];
                final selected = index == _dayPageIndex;
                final filled = _filledSlotCount(day);
                var skippedCount = 0;
                for (final s in _slots) {
                  if (_mealSkipped(day, s.key)) skippedCount++;
                }
                final completed = _completedSlotCount(day);
                final total = _slots.length;
                final complete = completed == total;
                final today = MealPlanWeekUtils.normalize(DateTime.now());
                final isToday = MealPlanWeekUtils.normalize(day) == today;
                final marker = _dayMarkerIcon(day);

                return GestureDetector(
                  onTap: () => _onDayChipTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 54,
                    padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary.withValues(
                              alpha: isDark ? 0.22 : 0.12,
                            )
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.35,
                            ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isToday
                            ? colorScheme.primary
                            : outline.withValues(alpha: 0.7),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          marker,
                          size: 14,
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.85,
                                ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          MealPlanWeekUtils.shortWeekdayLabel(day),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: selected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: completed / total,
                                strokeWidth: 2.8,
                                strokeCap: StrokeCap.round,
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.9),
                                color: skippedCount > 0 && filled == 0
                                    ? colorScheme.secondary
                                    : colorScheme.primary,
                              ),
                              Center(
                                child: complete
                                    ? Icon(
                                        skippedCount == total
                                            ? Icons.block_rounded
                                            : Icons.check_rounded,
                                        size: 24,
                                        color: skippedCount == total
                                            ? colorScheme.secondary
                                            : colorScheme.primary,
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              height: 1,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                          if (completed > 0 &&
                                              completed < total)
                                            Text(
                                              skippedCount > 0
                                                  ? '$filled+$skippedCount'
                                                  : '$filled/$total',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                height: 1,
                                                color: skippedCount > 0
                                                    ? colorScheme.secondary
                                                    : colorScheme.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading && _plans.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _dayPageIndex = i),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      final day = weekDays[index];
                      return RefreshIndicator(
                        color: colorScheme.primary,
                        onRefresh: () => _loadPlans(silent: true),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.xl + 48,
                          ),
                          children: [
                            Text(
                              MealPlanWeekUtils.fullWeekdayName(day),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              MealPlanWeekUtils.formatLongDate(day),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ..._slots.map((slot) {
                              final plan = _planFor(day, slot.key);
                              final skipped = _mealSkipped(day, slot.key);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _SlotCard(
                                  slotLabel: slot.label,
                                  plan: plan,
                                  skipped: skipped,
                                  resolvedImageUrl: resolveRecipeImageUrl(
                                    plan?.recipe?.imageUrl,
                                  ),
                                  outline: outline,
                                  onEmptyTap: () =>
                                      _assignRecipe(day, slot.key),
                                  onFilledTap: plan == null && !skipped
                                      ? null
                                      : () {
                                          if (plan != null) {
                                            _showSlotOptions(
                                              day,
                                              plan,
                                              slot.key,
                                            );
                                            return;
                                          }
                                          _showSkippedSlotOptions(
                                            day,
                                            slot.key,
                                            slot.label,
                                          );
                                        },
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final String slotLabel;
  final MealPlan? plan;
  final bool skipped;
  final String? resolvedImageUrl;
  final Color outline;
  final VoidCallback onEmptyTap;
  final VoidCallback? onFilledTap;

  const _SlotCard({
    required this.slotLabel,
    required this.plan,
    required this.skipped,
    required this.resolvedImageUrl,
    required this.outline,
    required this.onEmptyTap,
    required this.onFilledTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final recipe = plan?.recipe;
    final img = resolvedImageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: skipped
            ? onFilledTap
            : (plan == null ? onEmptyTap : onFilledTap),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: outline),
            color: skipped
                ? colorScheme.secondaryContainer.withValues(alpha: 0.22)
                : plan != null
                ? colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.06)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: skipped
                      ? _skippedPlaceholder(context)
                      : img != null && img.isNotEmpty
                      ? Image.network(
                          img,
                          fit: BoxFit.cover,
                          cacheWidth: 144,
                          errorBuilder: (context, error, stackTrace) =>
                              _placeholder(context),
                        )
                      : _placeholder(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slotLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (skipped)
                      Text(
                        'Skipped eating',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.secondary,
                        ),
                      )
                    else if (plan == null)
                      Text(
                        'Tap to add a recipe',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else ...[
                      Text(
                        recipe?.title ?? 'Planned',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (recipe != null && recipe.prepTime > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${recipe.prepTime} min',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (plan != null || skipped)
                Icon(Icons.more_horiz, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant_rounded,
        color: colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }

  Widget _skippedPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.secondaryContainer.withValues(alpha: 0.34),
      child: Icon(Icons.block_rounded, color: colorScheme.secondary, size: 28),
    );
  }
}
