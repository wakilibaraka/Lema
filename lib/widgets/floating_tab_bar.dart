import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating glass tab bar (Slice 3) — Apple News / Music loupe language.
///
/// Frosted pill floating over content (`extendBody: true`), 16pt side
/// margins, selected tab in a raised blue-tinted bubble. Content scrolls
/// visibly beneath it.
class FloatingTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<(IconData, String)> _items = [
    (CupertinoIcons.square_grid_2x2_fill, 'Lema'),
    (CupertinoIcons.device_phone_portrait, 'Simulator'),
    (CupertinoIcons.layers_alt, 'Queue'),
    (CupertinoIcons.calendar, 'Calendar'),
    (CupertinoIcons.sparkles, 'AI Studio'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C22).withAlpha(215)
                    : Colors.white.withAlpha(228),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(10),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (int i = 0; i < _items.length; i++)
                    Expanded(
                      child: _TabItem(
                        icon: _items[i].$1,
                        label: _items[i].$2,
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
    final active = const Color(0xFF007AFF);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? active.withAlpha(isDark ? 55 : 28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                size: 22,
                color: selected
                    ? active
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
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
