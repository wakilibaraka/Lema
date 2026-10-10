import 'package:flutter/material.dart';

/// Slice 12 — the "Netflix poster" glossy reflection.
///
/// A mirrored copy of [child] sits directly beneath it, masked with a
/// top-to-bottom alpha gradient so it reads as light bouncing off a surface.
///
/// It is deliberately a *static* reflection with **zero layout cost**: it
/// draws into whatever space the parent already reserved and never animates,
/// so it is safe to put inside scrollables and lists.
///
/// ```dart
/// PosterReflection(
///   child: Icon(CupertinoIcons.camera_fill, size: 22, color: accent),
///   peakAlpha: isDark ? 64 : 130,
/// )
/// ```
class PosterReflection extends StatelessWidget {
  final Widget child;

  /// Opacity of the reflection where it meets [child].
  /// Dark mode dims to 25% (`64`); light mode uses `130`.
  final int peakAlpha;

  /// How far the mirrored copy is allowed to bleed before it is cut off.
  /// Shorter values give a tighter, more "wet" gloss.
  final double height;

  /// Horizontal clip for the mirrored copy. Leave null to match [child]'s
  /// width (pass an explicit value when [child] is full-bleed).
  final double? width;

  const PosterReflection({
    super.key,
    required this.child,
    this.peakAlpha = 130,
    this.height = 10,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Tint the reflection from the child when possible so callers that tint
    // the icon (e.g. a selected tab going blue) get the matching gloss for
    // free. Falls back to the ambient foreground when the child has no colour.
    final tint = _tintOf(child) ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white54
            : Colors.black45);

    return SizedBox(
      height: height,
      width: width,
      child: ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withAlpha(peakAlpha), tint.withAlpha(0)],
        ).createShader(rect),
        blendMode: BlendMode.srcIn,
        child: ClipRect(
          child: Transform(
            // Pivot at the bottom edge so the mirror lands *below* the child.
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0),
            child: child,
          ),
        ),
      ),
    );
  }

  static Color? _tintOf(Widget child) {
    if (child is Icon) return child.color;
    return null;
  }
}