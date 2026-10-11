import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../theme/lema_motion.dart';

/// Deterministic, dependency-free sample artwork for showcases and empty
/// states. No network, no bundled assets — every frame is painted from a
/// seed, so it is stable across launches and safe to use in tests.
class SeededArtwork extends StatelessWidget {
  final int seed;
  final Color tint;
  final IconData glyph;
  final double stylize;

  const SeededArtwork({
    super.key,
    required this.seed,
    required this.tint,
    required this.glyph,
    this.stylize = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _SeededPainter(
            seed: seed,
            tint: tint,
            stylize: stylize,
            isDark: isDark,
          ),
        ),
        // Glyph plate — the "subject" of the photo.
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.42,
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withAlpha(isDark ? 46 : 120),
                      Colors.white.withAlpha(0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withAlpha(70),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  glyph,
                  size: 44,
                  color: Colors.white.withAlpha(isDark ? 210 : 240),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeededPainter extends CustomPainter {
  final int seed;
  final Color tint;
  final double stylize;
  final bool isDark;

  _SeededPainter({
    required this.seed,
    required this.tint,
    required this.stylize,
    required this.isDark,
  });

  double _rand(int salt) {
    // Cheap deterministic hash → 0..1.
    final x = math.sin((seed * 12.9898 + salt * 78.233)) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient.
    final base = HSLColor.fromColor(
      isDark ? const Color(0xFF0B0B10) : const Color(0xFFF3F2F7),
    );
    final end = HSLColor.fromColor(tint).withLightness(
      isDark ? 0.28 : 0.86,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.toColor(), Color.lerp(base.toColor(), end.toColor(), 0.9)!],
        ).createShader(rect),
    );

    // Soft colour blobs — the "lighting" of the photo.
    for (var i = 0; i < 5; i++) {
      final cx = _rand(i) * size.width;
      final cy = _rand(i + 10) * size.height;
      final r = size.shortestSide * (0.18 + _rand(i + 20) * 0.42);
      final colour = Color.lerp(tint, Colors.white, _rand(i + 30) * 0.5)!
          .withAlpha(((isDark ? 70 : 60) + stylize * 70).round());
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = colour
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
    }

    // Vignette so overlaid white type always reads.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withAlpha(isDark ? 90 : 40),
            Colors.transparent,
            Colors.black.withAlpha(isDark ? 170 : 90),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SeededPainter old) =>
      old.seed != seed || old.tint != tint || old.stylize != stylize;
}

/// Slice 13 — Intro swipe camera-click showcase.
///
/// Auto-cycling cards that demonstrate Lema's editing pipeline. Tapping the
/// floating shutter runs a full "shot": the frame blurs, the AI-styled result
/// crossfades in, a sheen sweeps across, and the carousel advances.
///
/// Design contract:
///  * one [AnimationController] drives the whole shot through named
///    [LemaMotion] segments — no magic numbers;
///  * it is fully deterministic and pausable, so it is testable headlessly;
///  * `prefers-reduced-motion` collapses the shot to a plain crossfade.
class ShowcaseCarousel extends StatefulWidget {
  /// Stable handle on the floating shutter, for tests and automation.
  static const shutterKey = ValueKey('lema_showcase_shutter');

  /// Stable handle on the always-visible onboarding escape control.
  static const skipKey = ValueKey('lema_showcase_skip');

  /// Stable handle on the final onboarding completion control.
  static const enterKey = ValueKey('lema_showcase_enter');

  final bool autoPlay;

  /// Fired once the user has advanced past the final card or hit Skip.
  final VoidCallback? onFinished;

  const ShowcaseCarousel({super.key, this.autoPlay = true, this.onFinished});

  /// Presents the showcase as a fullscreen, dismiss-on-finish overlay.
  ///
  /// [markSeen] persists the dismissal so the showcase only ever plays once
  /// on cold start; pass `false` when replaying it from Settings so the
  /// first-run flag is left untouched.
  static Future<void> present(
    BuildContext context, {
    bool markSeen = true,
  }) async {
    final navigator = Navigator.of(context);
    await navigator.push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withAlpha(150),
        transitionDuration: LemaMotion.emphasized,
        reverseTransitionDuration: LemaMotion.reverseStandard,
        pageBuilder: (_, _, _) => ShowcaseCarousel(
          autoPlay: true,
          onFinished: navigator.pop,
        ),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: LemaMotion.enter),
          child: child,
        ),
      ),
    );
    if (markSeen) {
      await StorageService.instance.setSeenIntroShowcase();
    }
  }

  @override
  State<ShowcaseCarousel> createState() => ShowcaseCarouselState();
}

class ShowcaseCarouselState extends State<ShowcaseCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shoot;
  final PageController _pages = PageController();
  Timer? _idle;
  int _index = 0;
  bool _reduceMotion = false;
  bool _busy = false;

  static const int _count = 3;
  static const Duration _dwell = Duration(milliseconds: 4600);

  static const ShowcaseSlide slide0 = ShowcaseSlide(
    seed: 7,
    tint: Color(0xFF6C5CE7),
    glyph: CupertinoIcons.camera_fill,
    title: 'Shoot once',
    caption: 'Point Lema at your camera roll or a connected phone.',
    styles: ['Original', 'Warm film', 'Neon night'],
    next: 'Then let AI style it',
  );
  static const ShowcaseSlide slide1 = ShowcaseSlide(
    seed: 21,
    tint: Color(0xFFF56040),
    glyph: CupertinoIcons.wand_stars,
    title: 'Let AI style it',
    caption: 'One tap restyles the frame, writes the caption and sizes it.',
    styles: ['Original', 'Studio pop', 'Mono grain'],
    next: 'Then schedule the drop',
  );
  static const ShowcaseSlide slide2 = ShowcaseSlide(
    seed: 43,
    tint: Color(0xFF00B894),
    glyph: CupertinoIcons.calendar_badge_plus,
    title: 'Schedule the drop',
    caption: 'Drag it into the calendar and every network publishes on time.',
    styles: ['Original', 'Clean cut', 'Bright pop'],
    next: "That's Lema",
  );

  static List<ShowcaseSlide> get _slides => const [slide0, slide1, slide2];

  @override
  void initState() {
    super.initState();
    _shoot = AnimationController(vsync: this, duration: _shotDuration)
      ..addStatusListener(_onShotStatus);
  }

  /// One full shot: blur-up, crossfade, sheen, hold.
  Duration get _shotDuration =>
      LemaMotion.emphasized + LemaMotion.emphasized;

  void _onShotStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _busy = false;
      _advance();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = LemaMotion.reduceMotionOf(context);
  }

  @override
  void dispose() {
    _idle?.cancel();
    _pages.dispose();
    _shoot.dispose();
    super.dispose();
  }

  // ── Auto-advance ──────────────────────────────────────────────────────

  void _restartIdle() {
    _idle?.cancel();
    if (!widget.autoPlay || _index >= _count - 1) return;
    _idle = Timer(_dwell, () {
      if (mounted && !_busy) _advance();
    });
  }

  void _advance() {
    if (_index >= _count - 1) return;
    final next = _index + 1;
    _pages.animateToPage(
      next,
      duration: LemaMotion.emphasized,
      curve: LemaMotion.emphasizedDecelerate,
    );
    setState(() => _index = next);
    _restartIdle();
  }

  void _finish() {
    _idle?.cancel();
    widget.onFinished?.call();
  }

  // ── The shot ──────────────────────────────────────────────────────────

  void fireShutter() {
    if (_busy) return;
    _idle?.cancel();
    setState(() => _busy = true);
    LemaMotion.impact();
    if (_reduceMotion) {
      _shoot
        ..duration = LemaMotion.standard
        ..forward();
    } else {
      _shoot
        ..duration = _shotDuration
        ..forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    _restartIdle();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0D0D12) : const Color(0xFFFBFBFD);

    return ColoredBox(
      color: surface,
      // The whole onboarding route respects the notch, status bar, and home
      // indicator. Controls are positioned inside this safe region rather
      // than at raw screen coordinates.
      child: SafeArea(
        child: Stack(
          children: [
          PageView.builder(
            controller: _pages,
            itemCount: _count,
            onPageChanged: (i) {
              setState(() => _index = i);
              _restartIdle();
            },
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return _Slide(
                slide: slide,
                shoot: _shoot,
                reduceMotion: _reduceMotion,
                isLast: i == _count - 1,
                onFinished: widget.onFinished,
              );
            },
          ),
          // Shutter — the hero control, floating over the page indicator.
          Positioned(
            left: 0,
            right: 0,
            bottom: 54,
            child: Center(child: _Shutter(animation: _shoot, onTap: fireShutter)),
          ),
          // Page indicator.
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: AnimatedBuilder(
              animation: _shoot,
              builder: (context, _) {
                // The indicator reacts to the shot — it "charges" as the
                // frame blurs, a small piece of shared motion language.
                final charge = _shoot.value.clamp(0.0, 1.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _count; i++)
                      AnimatedContainer(
                        duration: LemaMotion.quick,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _index ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: i == _index
                              ? _slides[_index].tint
                              : (isDark ? Colors.white24 : Colors.black26)
                                  .withAlpha(i == _index
                                      ? 255
                                      : (255 - (charge * 120).round())
                                          .clamp(0, 255)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 12,
            child: SizedBox(
              height: 44,
              child: FilledButton.tonal(
                key: ShowcaseCarousel.skipKey,
                onPressed: _finish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(108, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                child: const Text(
                  'Skip tour',
                  style: TextStyle(decoration: TextDecoration.none),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final ShowcaseSlide slide;
  final Animation<double> shoot;
  final bool reduceMotion;
  final bool isLast;
  final VoidCallback? onFinished;

  const _Slide({
    required this.slide,
    required this.shoot,
    required this.reduceMotion,
    required this.isLast,
    this.onFinished,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 140),
      child: AnimatedBuilder(
        animation: shoot,
        builder: (context, child) {
          final t = shoot.value.clamp(0.0, 1.0);

          // ── Named segments, all from LemaMotion ──────────────────────
          // A. 0.00–0.30  blur ramps up, frame recoils
          final blurT = LemaMotion.stagger(t, 0, count: 3, overlap: 0.2)
              .clamp(0.0, 1.0);
          // B. 0.28–0.62  original crossfades into the styled result
          final fade = LemaMotion.stagger(t, 1, count: 3, overlap: 0.2)
              .clamp(0.0, 1.0);
          // C. 0.58–1.00  sheen sweeps, then settles
          final sheen =
              LemaMotion.stagger(t, 2, count: 3, overlap: 0.2).clamp(0.0, 1.0);

          final sigma = reduceMotion ? 0.0 : (blurT * 11.0);
          final crossfade = reduceMotion ? (t > 0.5 ? 1.0 : 0.0) : fade;

          return Column(
            children: [
              // ── Viewfinder ───────────────────────────────────────────
              Expanded(
                child: Transform.scale(
                  // Recoil while capturing, settle on the result.
                  scale: 1 - (reduceMotion ? 0.0 : (0.04 * (1 - fade))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: sigma,
                            sigmaY: sigma,
                          ),
                          child: Opacity(
                            opacity: 1 - crossfade,
                            child: child,
                          ),
                        ),
                        Opacity(
                          opacity: crossfade,
                          child: SeededArtwork(
                            seed: slide.seed + 100,
                            tint: slide.tint,
                            glyph: slide.glyph,
                            stylize: 1,
                          ),
                        ),
                        // Sheen sweep — the light of the stylize pass.
                        if (!reduceMotion)
                          IgnorePointer(
                            child: Opacity(
                              opacity: sheen * (1 - sheen * 0.35),
                              child: ShaderMask(
                                shaderCallback: (rect) => LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withAlpha(150),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.35, 0.5, 0.65],
                                ).createShader(rect),
                                blendMode: BlendMode.srcIn,
                                child: Transform.translate(
                                  // -1.5x → +1.5x across the frame.
                                  offset: Offset(
                                    (sheen * 3 - 1.5) * 320,
                                    0,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        // Style chip rail — horizontally scrollable so it can never overflow
                        // at 402pt or at large accessibility text scales.
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: Row(
                              children: [
                                for (final style in slide.styles)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: _StyleChip(
                                      label: style,
                                      active: crossfade > 0.5
                                          ? style != slide.styles.first
                                          : style == slide.styles.first,
                                      tint: slide.tint,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // ── Copy ─────────────────────────────────────────────────
              Opacity(
                opacity: reduceMotion ? 1.0 : (1 - 0.25 * (1 - fade)),
                child: Column(
                  children: [
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: isDark ? Colors.white : Colors.black,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      slide.caption,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: isDark ? Colors.white60 : Colors.black54,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (isLast) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          key: ShowcaseCarousel.enterKey,
                          onPressed: onFinished,
                          style: FilledButton.styleFrom(
                            backgroundColor: slide.tint,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          child: const Text(
                            'Enter Lema',
                            style: TextStyle(decoration: TextDecoration.none),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Replay this tour anytime from Settings.',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ] else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_right,
                            size: 14,
                            color: slide.tint,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              slide.next,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: slide.tint,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        child: SeededArtwork(
          seed: slide.seed,
          tint: slide.tint,
          glyph: slide.glyph,
        ),
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onTap;

  const _Shutter({required this.animation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ShowcaseCarousel.shutterKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value.clamp(0.0, 1.0);
          // Press down through the first segment, then settle back.
          final press = t < 0.3
              ? LemaMotion.material.transform(t / 0.3)
              : 1 - LemaMotion.spring.transform((t - 0.3) / 0.7).clamp(0.0, 1.0);
          return Transform.scale(
            scale: 1 - (press * 0.12),
            child: child,
          );
        },
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: Colors.black12, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(46),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFE6E6EA)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color tint;

  const _StyleChip({
    required this.label,
    required this.active,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: LemaMotion.quick,
      curve: LemaMotion.standardCurve,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: active
            ? Colors.white.withAlpha(235)
            : Colors.black.withAlpha(92),
        border: Border.all(
          color: active ? tint.withAlpha(120) : Colors.white24,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          color: active ? const Color(0xFF14141A) : Colors.white70,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class ShowcaseSlide {
  final int seed;
  final Color tint;
  final IconData glyph;
  final String title;
  final String caption;
  final List<String> styles;
  final String next;

  const ShowcaseSlide({
    required this.seed,
    required this.tint,
    required this.glyph,
    required this.title,
    required this.caption,
    required this.styles,
    required this.next,
  });
}