import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme.dart';
import 'metrics.dart';

/// The single large chart in the app: reach over the selected window.
class TrendChart extends StatefulWidget {
  final List<TrendPoint> points;

  const TrendChart({super.key, required this.points});

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _selected;

  void _select(Offset position, double width) {
    final n = widget.points.length;
    if (n < 2) return;
    final x = (position.dx - _TrendPainter.leftGutter) /
        (width - _TrendPainter.leftGutter);
    setState(() => _selected = (x * (n - 1)).round().clamp(0, n - 1));
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final fmt = DateFormat.MMMd();
    final peak = points.fold<int>(0, (m, p) => math.max(m, p.reach));
    return Semantics(
      label: 'Reach trend from ${fmt.format(points.first.start)} to '
          '${fmt.format(points.last.end)}, peaking at '
          '${NumberFormat.compact().format(peak)} views',
      child: LayoutBuilder(
        builder: (context, box) => MouseRegion(
          onHover: (e) => _select(e.localPosition, box.maxWidth),
          onExit: (_) => setState(() => _selected = null),
          child: GestureDetector(
            onTapDown: (d) => _select(d.localPosition, box.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _select(d.localPosition, box.maxWidth),
            child: CustomPaint(
              size: Size(box.maxWidth, 240),
              painter: _TrendPainter(
                points: points,
                selected: _selected,
                line: Theme.of(context).colorScheme.primary,
                ink: Theme.of(context).colorScheme.onSurface,
                muted: Theme.of(context).colorScheme.onSurfaceVariant,
                surface: Theme.of(context).colorScheme.surface,
                grid: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  static const double leftGutter = 44;
  static const double bottomGutter = 24;
  static const double topGutter = 8;

  final List<TrendPoint> points;
  final int? selected;
  final Color line, ink, muted, surface, grid;

  _TrendPainter({
    required this.points,
    required this.selected,
    required this.line,
    required this.ink,
    required this.muted,
    required this.surface,
    required this.grid,
  });

  TextPainter _text(String s, Color color, {FontWeight? weight}) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: weight,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final plotW = size.width - leftGutter;
    final plotH = size.height - bottomGutter - topGutter;
    final peak = points.fold<int>(0, (m, p) => math.max(m, p.reach));
    final maxY = peak == 0 ? 1.0 : peak * 1.1;
    final compact = NumberFormat.compact();
    final dates = DateFormat.MMMd();

    Offset at(int i) => Offset(
          leftGutter + plotW * i / (points.length - 1),
          topGutter + plotH * (1 - points[i].reach / maxY),
        );

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topGutter + plotH * i / 3;
      canvas.drawLine(Offset(leftGutter, y), Offset(size.width, y), gridPaint);
      final label = _text(compact.format(maxY * (3 - i) / 3), muted);
      label.paint(canvas, Offset(0, y - label.height / 2));
    }

    final first = _text(dates.format(points.first.start), muted);
    first.paint(canvas, Offset(leftGutter, size.height - first.height));
    final last = _text(dates.format(points.last.end), muted);
    last.paint(canvas,
        Offset(size.width - last.width, size.height - last.height));

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final index = selected;
    if (index == null) return;
    final p = at(index);
    canvas.drawLine(Offset(p.dx, topGutter), Offset(p.dx, topGutter + plotH),
        gridPaint);
    canvas.drawCircle(p, 6, Paint()..color = surface);
    canvas.drawCircle(p, 4, Paint()..color = line);

    final point = points[index];
    final value = _text(compact.format(point.reach), ink, weight: FontWeight.w600);
    final range = _text(
        '${dates.format(point.start)} – ${dates.format(point.end)}', muted);
    final w = math.max(value.width, range.width) + LemaTheme.s4;
    final h = value.height + range.height + LemaTheme.s3;
    final left = (p.dx + LemaTheme.s2 + w > size.width)
        ? p.dx - LemaTheme.s2 - w
        : p.dx + LemaTheme.s2;
    final rect = RRect.fromLTRBR(left, topGutter, left + w, topGutter + h,
        const Radius.circular(LemaTheme.radiusControl));
    canvas.drawRRect(rect, Paint()..color = surface);
    canvas.drawRRect(
        rect,
        Paint()
          ..color = grid
          ..style = PaintingStyle.stroke);
    value.paint(canvas, Offset(left + LemaTheme.s2, topGutter + LemaTheme.s1));
    range.paint(canvas,
        Offset(left + LemaTheme.s2, topGutter + LemaTheme.s1 + value.height));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.selected != selected || old.line != line;
}
