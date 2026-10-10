import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lema's unified motion language.
///
/// Every signature interaction (Slices 11-15) draws its durations, curves,
/// stagger maths and haptics from here, so any future screen animates with
/// the same rhythm as the existing ones.
///
/// **Extend this file instead of hard-coding durations inline.** If a new
/// animation needs a timing that does not exist yet, add it here first — that
/// is what keeps Lema feeling like one app rather than a pile of widgets.
class LemaMotion {
  const LemaMotion._();

  // ── Durations ────────────────────────────────────────────────────────
  /// Press feedback, ripple-like ticks.
  static const Duration instant = Duration(milliseconds: 90);

  /// Small state swaps: tab selection, chip toggles, icon swaps.
  static const Duration quick = Duration(milliseconds: 180);

  /// The workhorse: sheet presentation, crossfades, small slides.
  static const Duration standard = Duration(milliseconds: 300);

  /// Hero / signature moments: morphs, page flips, expansions.
  static const Duration emphasized = Duration(milliseconds: 430);

  /// Deliberate, cinematic: intro showcase reveals.
  static const Duration slow = Duration(milliseconds: 620);

  /// Leaving should always be quicker than entering.
  static const Duration reverseStandard = Duration(milliseconds: 260);
  static const Duration reverseEmphasized = Duration(milliseconds: 320);

  // ── Curves ──────────────────────────────────────────────────────────
  /// Default for anything entering the screen. Fast out of the gate, long
  /// luxurious settle — reads as "Apple".
  static const Curve enter = Cubic(0.16, 1.0, 0.30, 1.0);

  /// Default for anything leaving. Accelerates away.
  static const Curve exit = Cubic(0.40, 0.0, 1.0, 1.0);

  /// Physical material: shelves, padding, expansion. No overshoot.
  static const Curve material = Cubic(0.20, 0.0, 0.0, 1.0);

  /// Playful overshoot for taps, cards, chips, page snaps.
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Softer overshoot for large surfaces where a big overshoot is nauseating.
  static const Curve springSoft = Cubic(0.25, 1.30, 0.45, 1.0);

  /// Heavy emphasis without overshoot — used for 3D transforms.
  static const Curve emphasize = Cubic(0.20, 0.90, 0.20, 1.0);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedDecelerate = Curves.easeOutQuart;

  // ── Stagger ─────────────────────────────────────────────────────────
  /// Default cadence between successive items in a staggered reveal.
  static const int staggerStepMs = 40;

  /// Delay before item [index] begins, for use with `Interval` /
  /// `AnimationController.forward(from: ...)`.
  static Duration staggerDelay(int index, {int stepMs = staggerStepMs}) =>
      Duration(milliseconds: index * stepMs);

  /// Maps one shared animation [t] (0..1) onto item [index]'s sub-interval.
  ///
  /// This is the workhorse for staggered reveals driven by a single
  /// controller — cheaper and less error-prone than one controller per row.
  ///
  /// ```dart
  /// final t = LemaMotion.stagger(controller.value, i, count: rows.length);
  /// final opacity = t;
  /// final dy = (1 - t) * 12;
  /// ```
  ///
  /// [overlap] is how much consecutive items share of the timeline:
  /// `0` = fully sequential, `1` = all items start together.
  static double stagger(
    double t,
    int index, {
    required int count,
    double overlap = 0.55,
    Curve curve = standardCurve,
  }) {
    final safeT = t.clamp(0.0, 1.0);
    if (count <= 1) return curve.transform(safeT);

    final step = (1.0 - overlap) / (count - 1);
    final start = (index * step).clamp(0.0, 1.0);
    // Remaining span after this item's start; guard the start==0 case.
    final span = (1.0 - start).abs() < 1e-6 ? 1.0 : (1.0 - start);
    return curve.transform(((safeT - start) / span).clamp(0.0, 1.0));
  }

  /// Convenience wrapper: eased vertical travel for staggered entrances.
  static Offset staggerSlide(double t, int index,
      {required int count, double distance = 14, double overlap = 0.55}) {
    final eased = stagger(t, index, count: count, overlap: overlap);
    return Offset(0, (1 - eased) * distance);
  }

  // ── Reduced motion ──────────────────────────────────────────────────
  /// True when the user has asked the OS to reduce motion.
  ///
  /// Every signature animation should branch on this and fall back to a
  /// crossfade or an instant swap — never simply play at a faster speed.
  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  // ── Haptics ─────────────────────────────────────────────────────────
  /// Light tap: tab changes, chips, scroll snaps.
  static void tap() => HapticFeedback.selectionClick();

  /// Medium impact: shutter, hero card open, a committed action.
  static void impact() => HapticFeedback.mediumImpact();

  /// Heavy impact: a big reveal settling into place.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Success pattern: a post published, a card saved.
  static void success() => HapticFeedback.mediumImpact();
}

// ── Shared interpolators ───────────────────────────────────────────────

double lerpDouble(double a, double b, double t) =>
    a < b ? a + (b - a) * t : b + (a - b) * t;

double lerpDoubleInverted(double a, double b, double t) =>
    a + (b - a) * t;

Color lerpColor(Color a, Color b, double t) =>
    Color.lerp(a, b, t.clamp(0.0, 1.0))!;

/// Interpolates between two rects — the backbone of every Lema morph.
Rect lerpRect(Rect a, Rect b, double t) => Rect.lerp(a, b, t.clamp(0.0, 1.0))!;

/// Interpolates between two radii without going negative mid-flight.
double lerpRadius(double a, double b, double t) =>
    lerpDouble(a, b, t).clamp(0.0, double.infinity);