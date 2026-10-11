import 'package:flutter/material.dart';

import '../theme/lema_motion.dart';

/// Slice 23 — the single filter-pill implementation for the whole app.
///
/// Home, Queue and Simulator previously carried three copies of this exact
/// widget (radius 20, 16/9 padding, black/white selected fill). New filter
/// rows must use this instead of copying it again.
class LemaPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  /// Optional leading brand dot (platform pills).
  final Color? dot;

  const LemaPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
    this.dot,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: LemaMotion.quick,
        curve: LemaMotion.standardCurve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark
                  ? Colors.white.withAlpha(12)
                  : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(10)),
          ),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 30 : 8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                  width: 7,
                  height: 7,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}