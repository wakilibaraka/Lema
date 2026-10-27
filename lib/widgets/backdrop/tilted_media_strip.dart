import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/post_model.dart';
import '../../theme/backdrop_theme.dart';
import '../media_player_widget.dart';

/// Backdrop's tilted photo strip: up to four post thumbnails, each rotated a
/// few degrees inside a white print border with a soft shadow, plus the
/// dashed "add" tile that opens the composer (LEMA_DESIGN_PLAN.md §2).
///
/// Every player runs `thumbnail: true, autoPlay: false` — the media matrix
/// test pins exactly one autoplay player in the app (the hero).
class TiltedMediaStrip extends StatelessWidget {
  /// The day's posts, already time-sorted by the caller.
  final List<PostModel> posts;
  final VoidCallback onAdd;
  final ValueChanged<PostModel> onOpen;

  const TiltedMediaStrip({
    super.key,
    required this.posts,
    required this.onAdd,
    required this.onOpen,
  });

  /// Slightly different tilt per slot so the stack reads as scattered
  /// prints, not a repeating pattern.
  static const List<double> _tilt = [-0.065, 0.05, -0.035, 0.06];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shown = posts.take(4).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < shown.length; i++)
          _TiltedTile(
            post: shown[i],
            tilt: _tilt[i % _tilt.length],
            isDark: isDark,
            onTap: () => onOpen(shown[i]),
          ),
        _AddTile(isDark: isDark, onTap: onAdd),
      ],
    );
  }
}

class _TiltedTile extends StatelessWidget {
  final PostModel post;
  final double tilt;
  final bool isDark;
  final VoidCallback onTap;

  const _TiltedTile({
    required this.post,
    required this.tilt,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: tilt,
        child: Container(
          width: 80,
          height: 104,
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            // White print border in both modes — the photo-print look.
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 28),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11.5),
            child: UniversalMediaPlayer(
              mediaUrl: post.mediaUrl,
              isVideo: post.isVideo,
              autoPlay: false,
              showControls: false,
              thumbnail: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed magenta "add" tile — the compose affordance from the reference
/// feed's empty event card.
class _AddTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddTile({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a post',
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: BackdropTheme.accent.withAlpha(isDark ? 140 : 170),
          ),
          child: const SizedBox(
            width: 80,
            height: 104,
            child: Icon(
              CupertinoIcons.plus,
              size: 26,
              color: BackdropTheme.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;

  _DashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    const dash = 6.0;
    const gap = 5.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        canvas.drawPath(metric.extractPath(dist, dist + dash), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}
