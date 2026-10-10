import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/lema_motion.dart';

/// Month accent language for Lema calendars.
///
/// Slice 15: the accent shifts *dynamically* across a month boundary rather
/// than snapping — July red flows into August blue as the days tick over, so
/// a month change is felt rather than read.
///
/// Returned as a resolved colour so any widget can ask for "the accent on
/// this exact day" without re-implementing the ramp.
class LemaMonthAccent {
  const LemaMonthAccent._();

  /// Twelve anchors, one per month. Deliberately warm in the second half of
  /// the year and cool in the first, so the calendar visibly turns over.
  static const List<Color> _anchors = [
    Color(0xFF5E5CE6), // Jan — indigo
    Color(0xFF0A84FF), // Feb — blue
    Color(0xFF00A5B5), // Mar — teal
    Color(0xFF30B57C), // Apr — green
    Color(0xFF7FB800), // May — lime
    Color(0xFFFF9F0A), // Jun — amber
    Color(0xFFFF3B30), // Jul — red
    Color(0xFF0A84FF), // Aug — blue  (plan: July red → August blue)
    Color(0xFF5E5CE6), // Sep — indigo
    Color(0xFFFF375F), // Oct — pink
    Color(0xFFFF9F0A), // Nov — amber
    Color(0xFFFF3B30), // Dec — red
  ];

  /// Days in [month] of [year].
  static int daysIn(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;

  /// Accent colour for the exact instant of [date], blended between the
  /// current month's anchor and the next month's.
  static Color resolve(DateTime date) {
    final m = date.month - 1;
    final from = _anchors[m % _anchors.length];
    final to = _anchors[(m + 1) % _anchors.length];
    // Ramp across the month: 0 on the 1st, 1 on the last day.
    final t = ((date.day - 1) / math.max(1, daysIn(date) - 1)).clamp(0.0, 1.0);
    return Color.lerp(from, to, t)!;
  }

  /// Soft variant for fills behind white type.
  static Color resolveSoft(DateTime date, {double opacity = 0.16}) =>
      resolve(date).withAlpha((opacity * 255).round());
}

/// A tear-away notched divider — the "daily page" paper metaphor.
///
/// Purely decorative, zero animation cost, and safe inside lists.
class TearLine extends StatelessWidget {
  final Color color;

  const TearLine({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 8,
      child: CustomPaint(
        painter: _TearLinePainter(color),
        size: Size.infinite,
      ),
    );
  }
}

class _TearLinePainter extends CustomPainter {
  final Color color;

  _TearLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const notch = 9.0;
    final y = size.height / 2;
    final path = Path()..moveTo(0, y);

    var x = 0.0;
    var up = true;
    while (x < size.width) {
      final next = math.min(x + notch * 2, size.width);
      // Perforation: a shallow arc in, a sharp notch out.
      path.quadraticBezierTo((x + next) / 2, up ? y - 3.2 : y + 3.2, next, y);
      x = next;
      up = !up;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TearLinePainter old) => old.color != color;
}

/// Reusable 3D page-flip swap.
///
/// An [AnimatedSwap] wrapper that rotates the outgoing page away around Y
/// and swings the incoming page in, exactly like turning a calendar leaf.
/// Honours reduced motion by collapsing to a crossfade.
///
/// ```dart
/// PageFlipSwap(
///   forward: true,
///   child: Text('$day', key: ValueKey(day)),
/// )
/// ```
class PageFlipSwap extends StatelessWidget {
  final Widget child;
  final bool forward;

  /// Set false for horizontal content that has no notion of direction.
  final bool flip;

  const PageFlipSwap({
    super.key,
    required this.child,
    this.forward = true,
    this.flip = true,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = LemaMotion.reduceMotionOf(context);

    return AnimatedSwitcher(
      duration: LemaMotion.emphasized,
      switchInCurve: LemaMotion.emphasize,
      switchOutCurve: LemaMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        if (reduce || !flip) {
          return FadeTransition(opacity: animation, child: child);
        }
        // `forward` flips which way the leaf turns.
        final sign = forward ? 1.0 : -1.0;
        final incoming = child.key == this.child.key;
        final t = animation.value.clamp(0.0, 1.0);

        // Incoming starts at 82° and settles flat; outgoing mirrors it.
        final angle = (incoming ? (1 - t) : t) * (math.pi / 1.85) * sign;
        // Slight lift so the leaf reads as a physical page, not a decal.
        final lift = (1 - (2 * t - 1).abs()) * 0.06;

        return Opacity(
          // Fade only in the last third so the page stays legible.
          opacity: t < 0.66 ? 1.0 : (1 - (t - 0.66) / 0.34).clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateY(angle)
              ..scaleByDouble(1 + lift, 1 + lift, 1, 1),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Slice 15 — the daily page-flip calendar header.
///
/// Big day digits that page-flip when the day changes, a tear-away notched
/// rule, and lunar / moon / fortune indicators that fade and slide on the same
/// LemaMotion stagger as every other reveal in the app.
class DayFlipHeader extends StatefulWidget {
  final DateTime day;
  final Color? accent;
  final bool isDark;

  const DayFlipHeader({
    super.key,
    required this.day,
    required this.isDark,
    this.accent,
  });

  @override
  State<DayFlipHeader> createState() => _DayFlipHeaderState();
}

class _DayFlipHeaderState extends State<DayFlipHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: LemaMotion.slow,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  /// Which way the leaf should turn: forward when moving to a later day.
  bool _forwardFrom(DateTime previous) {
    final a = DateTime(widget.day.year, widget.day.month, widget.day.day);
    final b = DateTime(previous.year, previous.month, previous.day);
    return a.isAfter(b);
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final accent = widget.accent ?? LemaMonthAccent.resolve(day);
    final isDark = widget.isDark;
    final reduce = LemaMotion.reduceMotionOf(context);

    final lunar = _LunarStub.of(day);
    final moon = _MoonPhase.of(day);
    final fortune = _Fortune.of(day);

    final indicators = <({IconData icon, String label, Color colour})>[
      (icon: CupertinoIcons.moon_stars, label: lunar.label, colour: accent),
      (icon: moon.icon, label: moon.label, colour: isDark ? Colors.white70 : Colors.black54),
      (icon: CupertinoIcons.sparkles, label: fortune.label, colour: const Color(0xFFFFB020)),
    ];

    Widget indicator(int i) {
      final t = reduce
          ? 1.0
          : LemaMotion.stagger(_enter.value, i, count: indicators.length,
              overlap: 0.6, curve: LemaMotion.enter);
      final item = indicators[i];
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset((1 - t) * 10, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: item.colour.withAlpha(isDark ? 30 : 22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 11, color: item.colour),
                const SizedBox(width: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withAlpha(isDark ? 34 : 20),
            (isDark ? Colors.white : Colors.white).withAlpha(isDark ? 10 : 200),
          ],
        ),
        border: Border.all(color: accent.withAlpha(isDark ? 60 : 46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── The flipping digits ────────────────────────────────
              SizedBox(
                // Fixed box: the digits must never be clipped or reflow the
                // row when they swap, whatever the day number's width.
                width: 84,
                height: 78,
                child: PageFlipSwap(
                  forward: _forwardFrom(day),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        '${day.day}',
                        key: ValueKey(
                            '${day.year}-${day.month}-${day.day}'),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 64,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -3,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Month + weekday, flips with the digits ────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PageFlipSwap(
                      forward: _forwardFrom(day),
                      child: Text(
                        _monthYear(day),
                        key: ValueKey('m-${day.year}-${day.month}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    PageFlipSwap(
                      forward: _forwardFrom(day),
                      child: Text(
                        _weekday(day),
                        key: ValueKey('w-${day.year}-${day.month}-${day.day}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TearLine(color: accent.withAlpha(isDark ? 70 : 50)),
          const SizedBox(height: 10),
          // ── Indicators, staggered in on arrival ──────────────────
          Row(
            children: [
              for (var i = 0; i < indicators.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Flexible(child: indicator(i)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _monthYear(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  static String _weekday(DateTime d) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return days[d.weekday - 1];
  }
}

/// Deterministic lunar label — stubbed locally, no backend (Slice 15 scope).
class _LunarStub {
  final String label;

  const _LunarStub(this.label);

  static const List<String> _stems = [
    'Ji', 'Chou', 'Yin', 'Mao', 'Chen', 'Si', 'Wu', 'Wei', 'Shen', 'You', 'Xu', 'Hai',
  ];
  static const List<String> _branches = [
    'Zi', 'Chou', 'Yin', 'Mao', 'Chen', 'Si',
    'Wu', 'Wei', 'Shen', 'You', 'Xu', 'Hai',
  ];

  static _LunarStub of(DateTime d) {
    // ~29.53-day synodic month anchored to a fixed epoch: stable, local,
    // and good enough for a showcase surface.
    const epochDays = 20000;
    final days = d.difference(DateTime.utc(2024, 1, 1)).inDays;
    final offset = (days - epochDays) % 60;
    final safe = offset < 0 ? offset + 60 : offset;
    final stem = _stems[safe % 12];
    final branch = _branches[safe % 12];
    return _LunarStub('$stem$branch');
  }
}

/// Deterministic moon phase from the day of month.
class _MoonPhase {
  final IconData icon;
  final String label;

  const _MoonPhase(this.icon, this.label);

  static _MoonPhase of(DateTime d) {
    const phases = [
      ('New', CupertinoIcons.moon),
      ('Waxing', CupertinoIcons.moon_stars),
      ('Full', CupertinoIcons.moon_fill),
      ('Waning', CupertinoIcons.moon_stars),
    ];
    const length = 29;
    final idx = ((d.day - 1) * phases.length / length).floor().clamp(0, 3);
    final p = phases[idx];
    return _MoonPhase(p.$2, p.$1);
  }
}

/// Deterministic fortune level — playful, local, deterministic per day.
class _Fortune {
  final String label;

  const _Fortune(this.label);

  static _Fortune of(DateTime d) {
    const levels = ['Low', 'Steady', 'Good', 'Great'];
    final seed = (d.year * 372 + d.month * 31 + d.day) % levels.length;
    return _Fortune(levels[seed]);
  }
}