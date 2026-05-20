import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:wellnest/theme/app_spacing.dart';
import 'package:wellnest/theme/app_theme.dart';

/// Solid [BottomAppBar] with center notch for a docked FAB ([CircularNotchedRectangle]).
/// Pair [fab] + [fabLocation] with the root [Scaffold].
class CustomBottomNav extends StatelessWidget {
  /// Standard FAB diameter + notch clearance.
  static const double fabClearanceWidth = 56;

  static const double _navIconSize = 24 * 1.2;

  static const FloatingActionButtonLocation fabLocation =
      FloatingActionButtonLocation.centerDocked;

  static Widget fab({required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.58),
          width: 1.25,
        ),
      ),
      child: FloatingActionButton(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 8,
        onPressed: onPressed,
        tooltip: 'Create',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mq = MediaQuery.of(context);
    final topPad = AppSpacing.md;
    final bottomPad = AppSpacing.md + mq.viewPadding.bottom;
    final barHeight =
        56 + AppSpacing.md + AppSpacing.sm + mq.viewPadding.bottom;
    final geometryListenable = Scaffold.geometryOf(context);
    final isLight = scheme.brightness == Brightness.light;
    final glassTint = isLight
        ? Colors.white.withValues(alpha: 0.94)
        : scheme.surface.withValues(alpha: 0.94);
    final outlineColor = wellnestOutlineColor(context);

    return MediaQuery(
      data: mq.copyWith(
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 4,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            color: glassTint,
            padding: EdgeInsets.zero,
            height: barHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  topPad,
                  AppSpacing.md,
                  bottomPad,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DockNavItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Discover',
                        selected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                    ),
                    Expanded(
                      child: _DockNavItem(
                        icon: Icons.dynamic_feed_rounded,
                        label: 'Feed',
                        selected: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                    ),
                    const SizedBox(width: fabClearanceWidth),
                    Expanded(
                      child: _DockNavItem(
                        icon: Icons.bookmark_rounded,
                        label: 'Saved',
                        selected: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                    ),
                    Expanded(
                      child: _DockNavItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        selected: currentIndex == 3,
                        onTap: () => onTap(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: barHeight,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _NotchedBottomBarOutlinePainter(
                  geometryListenable: geometryListenable,
                  notchMargin: 4,
                  strokeColor: outlineColor,
                  strokeWidth: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Matches [BottomAppBar] clip logic so the stroke follows the notch + FAB cutout.
class _NotchedBottomBarOutlinePainter extends CustomPainter {
  _NotchedBottomBarOutlinePainter({
    required this.geometryListenable,
    required this.notchMargin,
    required this.strokeColor,
    required this.strokeWidth,
  }) : super(repaint: geometryListenable);

  final ValueListenable<ScaffoldGeometry> geometryListenable;
  final double notchMargin;
  final Color strokeColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final ScaffoldGeometry g = geometryListenable.value;
    final double? barTopGlobal = g.bottomNavigationBarTop;
    final Rect? fabGlobal = g.floatingActionButtonArea;
    if (barTopGlobal == null || fabGlobal == null) return;

    final Rect host = Offset.zero & size;
    final Rect button = fabGlobal
        .translate(0, -barTopGlobal)
        .inflate(notchMargin);
    final Path path = const CircularNotchedRectangle().getOuterPath(
      host,
      button,
    );

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = strokeColor
      ..isAntiAlias = true;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBottomBarOutlinePainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.notchMargin != notchMargin;
  }
}

class _DockNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = cs.primary;
    final inactive = cs.onSurfaceVariant;
    final color = selected ? active : inactive;

    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Icon(icon, size: CustomBottomNav._navIconSize, color: color),
        ),
      ),
    );
  }
}
