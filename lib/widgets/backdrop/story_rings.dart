import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/backdrop_theme.dart';

/// One entry in the Backdrop-style story ring row.
class StoryRingData {
  final String label;
  final IconData icon;
  final Color color;

  /// Renders the "New post" compose affordance (+ badge, grey ring).
  final bool isNew;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  const StoryRingData({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isNew = false,
    this.selected = false,
    this.dim = false,
  });
}

/// Horizontal row of gradient story rings (Instagram feed pattern).
///
/// First ring is the compose affordance; the rest are platform filters
/// driven by `platformsMap` (LEMA_DESIGN_PLAN.md §2). Selection mirrors the
/// grid's existing platform filter pills — tapping a ring is the same
/// filter, in feed language.
class StoryRingsRow extends StatelessWidget {
  final List<StoryRingData> rings;

  const StoryRingsRow({super.key, required this.rings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      // Ring (62) + gap (7) + label line-height (~15) must never touch the
      // row's bottom edge — a 1px RenderFlex overflow here failed 15 tests.
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        itemCount: rings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) =>
            _StoryRingTile(data: rings[i], isDark: isDark),
      ),
    );
  }
}

class _StoryRingTile extends StatelessWidget {
  final StoryRingData data;
  final bool isDark;

  const _StoryRingTile({required this.data, required this.isDark});

  static const double _ringSize = 62;

  @override
  Widget build(BuildContext context) {
    final labelColor = data.dim
        ? BackdropTheme.inkTertiary(isDark)
        : BackdropTheme.ink(isDark);
    return Semantics(
      button: true,
      label: data.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          data.onTap();
        },
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Ring: gradient stroke, canvas gap, then the avatar.
                  Container(
                    width: _ringSize,
                    height: _ringSize,
                    padding: const EdgeInsets.all(3),
                    decoration: data.isNew
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 2,
                            ),
                          )
                        : BackdropTheme.ringDecoration(
                            dim: data.dim, selected: data.selected),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? const Color(0xFF26262C)
                            : BackdropTheme.card(isDark),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: data.color.withAlpha(data.dim ? 25 : 32),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          data.isNew ? CupertinoIcons.plus : data.icon,
                          size: data.isNew ? 22 : 23,
                          color: data.dim
                              ? BackdropTheme.inkTertiary(isDark)
                              : data.color,
                        ),
                      ),
                    ),
                  ),
                  if (data.isNew)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 21,
                        height: 21,
                        decoration: BoxDecoration(
                          color: BackdropTheme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF0E0E10)
                                : const Color(0xFFF5F5F8),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.plus,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: data.selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.1,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
