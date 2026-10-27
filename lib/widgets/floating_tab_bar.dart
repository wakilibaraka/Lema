import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nav_destination.dart';
import '../theme/backdrop_theme.dart';
import '../theme/lema_motion.dart';
import 'poster_reflection.dart';

/// Docked glass tab bar (Slice 3 floating pill → Slice 20 Photos dock).
///
/// Apple Photos language: full-width frosted bar, rounded top corners,
/// background extending under the home indicator (manual bottom inset, no
/// SafeArea gap). Selected tab keeps the raised bubble (Backdrop magenta —
/// the Home accent), the Slice-12 poster reflections, and the spring scale.
/// Content scrolls visibly beneath it (`extendBody: true`).
class FloatingTabBar extends StatelessWidget {
  /// Selected dock index, or -1 when the active screen is not in the dock.
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// Height the bar occupies over the content, so a page can reserve room
  /// for it instead of hiding its final row underneath the frost.
  static const double _contentHeight = 58;

  static double clearance(BuildContext context) =>
      _contentHeight + MediaQuery.of(context).viewPadding.bottom;

  /// Items come from the shared destination list — the dock labels can no
  /// longer drift from the sidebar and title bar.
  List<NavDestination> get _items => lemaDockDestinations;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Slice 20: extend under the home indicator like Photos — the inset is
    // absorbed inside the frost instead of a SafeArea gap below the bar.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    const radius = BorderRadius.only(
      topLeft: Radius.circular(28),
      topRight: Radius.circular(28),
    );
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          // The bar's own height: 8pt frame + item content + 8pt frame,
          // with the home-indicator inset absorbed inside the frost.
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C22).withAlpha(215)
                : Colors.white.withAlpha(228),
            borderRadius: radius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 25),
                blurRadius: 24,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Row(
            children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(
                  child: _TabItem(
                    icon: _items[i].icon,
                    label: _items[i].shortLabel,
                    // `currentIndex` is -1 when the active screen lives
                    // outside the dock, so nothing claims to be selected.
                    selected: i == currentIndex,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onTap(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Backdrop accent replaces the old system-blue bubble.
    final active = BackdropTheme.accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: LemaMotion.quick,
        curve: LemaMotion.standardCurve,
        // Slice 12: padding tightened to absorb the reflection height so the
        // bar's overall footprint does not shift.
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? active.withAlpha(isDark ? 55 : 28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabIcon(
              icon: icon,
              color: selected
                  ? active
                  : (isDark ? Colors.white54 : Colors.black45),
              scale: selected ? 1.12 : 1.0,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.1,
                color: selected
                    ? active
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slice 12 — Netflix-poster style reflection under a tab icon.
///
/// Uses the shared [PosterReflection] and the shared icon size so the gloss
/// matches every other reflection in the app.
class _TabIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double scale;

  const _TabIcon({
    required this.icon,
    required this.color,
    required this.scale,
  });

  static const double _size = 22;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: scale,
          duration: LemaMotion.quick,
          child: Icon(icon, size: _size, color: color),
        ),
        PosterReflection(
          width: _size,
          // Dark mode dims the reflection to 25%.
          peakAlpha: Theme.of(context).brightness == Brightness.dark ? 64 : 130,
          child: Icon(icon, size: _size, color: color),
        ),
      ],
    );
  }
}
