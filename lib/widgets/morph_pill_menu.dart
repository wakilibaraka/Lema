import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/apple_theme.dart';

/// Slice 11 — Circle menu dropdown morph.
///
/// A topic pill in the Lema filter bar expands and morphs into a centred
/// floating modal card with a spring response; action items stagger in with
/// a fade + scale cascade; dismissing reverses the transition, shrinking and
/// morphing the card back into its originating pill position.
///
/// Motion spec (shared with Slices 12-15): spring curves, haptics on
/// trigger + settle, `prefers-reduced-motion` honoured with a plain fade.

class MorphPillMenuItem {
  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback? onTap;
  final bool selected;
  final bool destructive;

  const MorphPillMenuItem({
    required this.icon,
    required this.label,
    this.detail,
    this.onTap,
    this.selected = false,
    this.destructive = false,
  });
}

class MorphPillMenuSpec {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<MorphPillMenuItem> items;

  const MorphPillMenuSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.items,
  });
}

class MorphPillMenu {
  /// Opens the morphing card anchored to [anchorKey]'s current rect.
  static void show(
    BuildContext context, {
    required GlobalKey anchorKey,
    required MorphPillMenuSpec spec,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _MorphPillOverlay(
        anchorKey: anchorKey,
        spec: spec,
        onClosed: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _MorphPillOverlay extends StatefulWidget {
  final GlobalKey anchorKey;
  final MorphPillMenuSpec spec;
  final VoidCallback onClosed;

  const _MorphPillOverlay({
    required this.anchorKey,
    required this.spec,
    required this.onClosed,
  });

  @override
  State<_MorphPillOverlay> createState() => _MorphPillOverlayState();
}

class _MorphPillOverlayState extends State<_MorphPillOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Rect _fromRect = Rect.zero;
  Rect _toRect = Rect.zero;
  bool _measured = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    // Inherited widgets (MediaQuery) must NOT be read here — measured in
    // didChangeDependencies instead.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 430),
      reverseDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_measured) return;
    _measured = true;

    final screen = MediaQuery.sizeOf(context);
    _fromRect = _measureAnchor() ??
        Rect.fromCenter(
          center: Offset(screen.width / 2, screen.height / 2),
          width: 120,
          height: 40,
        );
    final cardWidth = (screen.width - 48).clamp(160.0, 360.0);
    final cardHeight = (88 + widget.spec.items.length * 62.0)
        .clamp(160.0, screen.height * 0.72);
    _toRect = Rect.fromCenter(
      center: Offset(screen.width / 2, screen.height * 0.42),
      width: cardWidth,
      height: cardHeight,
    );
    _controller.forward();
  }

  Rect? _measureAnchor() {
    final box = widget.anchorKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    _controller.reverse().then((_) {
      if (mounted) widget.onClosed();
    });
  }

  void _handleItem(MorphPillMenuItem item) {
    HapticFeedback.selectionClick();
    item.onTap?.call();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spec = widget.spec;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final geometry = _reduceMotion
            ? t
            : Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
        final rect = Rect.lerp(_fromRect, _toRect, geometry);
        final radius = lerpDouble(20, 28, geometry);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: ColoredBox(
                  color: Colors.black.withAlpha((70 * t).round()),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect ?? _toRect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C22).withAlpha(238)
                          : Colors.white.withAlpha(244),
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: spec.accent.withAlpha(
                            lerpDouble(40, 120, t).round()),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 120 : 45),
                          blurRadius: lerpDouble(10, 34, geometry),
                          offset:
                              Offset(0, lerpDouble(3, 16, geometry)),
                        ),
                      ],
                    ),
                      // Clipped, never scrollable: while the card morphs up
                      // from the pill rect (120x40) its full content is
                      // briefly larger than the frame — clip instead of
                      // reporting an overflow.
                      child: ClipRect(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: _buildCard(context, isDark, t, geometry),
                        ),
                      ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(
      BuildContext context, bool isDark, double t, double geometry) {
    final spec = widget.spec;
    final muted = isDark ? Colors.white54 : Colors.black54;

    Widget row(MorphPillMenuItem item, int index) {
      // Slice 11: 40ms cascade, fade + scale per item.
      final start = (0.28 + index * 0.09).clamp(0.0, 1.0);
      final itemT = _reduceMotion
          ? t
          : ((t - start) / (1 - start)).clamp(0.0, 1.0);
      final eased = Curves.easeOutBack.transform(itemT);
      final color = item.destructive
          ? AppleTheme.systemRed
          : (isDark ? Colors.white : Colors.black87);
      return Opacity(
        opacity: itemT,
        child: Transform.scale(
          scale: 0.90 + 0.10 * eased,
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleItem(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: (item.destructive
                              ? AppleTheme.systemRed
                              : spec.accent)
                          .withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      size: 15,
                      color: item.destructive
                          ? AppleTheme.systemRed
                          : spec.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: item.selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: color,
                          ),
                        ),
                        if (item.detail != null)
                          Text(
                            item.detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (item.selected)
                    Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 17,
                      color: spec.accent,
                    )
                  else
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 13,
                      color: muted,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final headerT = _reduceMotion
        ? t
        : Curves.easeOut.transform((t / 0.45).clamp(0.0, 1.0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: headerT,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - headerT)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: spec.accent.withAlpha(32),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(spec.icon,
                          size: 17, color: spec.accent),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            spec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color:
                                  isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            spec.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _dismiss,
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        size: 21,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withAlpha(26)
                : Colors.black.withAlpha(18),
          ),
          for (int i = 0; i < spec.items.length; i++)
            row(spec.items[i], i),
        ],
      ),
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;
