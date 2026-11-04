import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/post_model.dart';
import '../../core/providers/posts_provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/on_air_tick.dart';

/// Where a post lands when dropped on an hour: it keeps its minutes.
DateTime dropTime(DateTime day, int hour, DateTime original) =>
    DateTime(day.year, day.month, day.day, hour, original.minute);

const double _hourHeight = 52;
const double _blockHeight = 44;
const double _labelWidth = 44;
const double _edgeZone = 48;

/// An hour grid of 7 days, or 3 on a phone. All 24 hours exist so an early
/// post is never hidden; the grid opens at the first post showing, or 06:00.
class WeekView extends StatefulWidget {
  const WeekView({super.key});

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  final GlobalKey _openingHour = GlobalKey();
  final GlobalKey _grid = GlobalKey();
  final ScrollController _scroll = ScrollController();
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _openingHour.currentContext;
      if (target != null) Scrollable.ensureVisible(target);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls while a dragged post is held near the top or bottom edge, so it
  /// can reach an hour that isn't showing.
  void _edgeScroll(Offset pointer) {
    final box = _grid.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final y = box.globalToLocal(pointer).dy;
    final step = y < _edgeZone ? -8.0 : (y > box.size.height - _edgeZone ? 8.0 : 0.0);
    if (step == 0) return;
    final p = _scroll.position;
    _scroll.jumpTo((p.pixels + step).clamp(p.minScrollExtent, p.maxScrollExtent));
  }

  void _shift(int days) => setState(() {
        _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + days);
      });

  void _drop(PostModel post, DateTime day, int hour) {
    final posts = context.read<PostsProvider>();
    final when = dropTime(day, hour, post.scheduledTime);
    posts.reschedulePost(post.id, when);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Moved to ${DateFormat('EEE, MMM d, HH:mm').format(when)}'),
        action: SnackBarAction(label: 'Undo', onPressed: posts.undoLastReorder),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final count = MediaQuery.sizeOf(context).width < 600 ? 3 : 7;
    final start = count == 7
        ? DateTime(_anchor.year, _anchor.month, _anchor.day - _anchor.weekday + 1)
        : _anchor;
    final days = [
      for (var i = 0; i < count; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
    final posts = context.watch<PostsProvider>().posts;

    List<PostModel> at(DateTime day, int hour) => posts.where((p) {
          final t = p.scheduledTime;
          return t.year == day.year &&
              t.month == day.month &&
              t.day == day.day &&
              t.hour == hour;
        }).toList()
          ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final shownHours = [
      for (final p in posts)
        if (days.any((d) => DateUtils.isSameDay(d, p.scheduledTime)))
          p.scheduledTime.hour,
    ];
    final openingHour = shownHours.isEmpty ? 6 : shownHours.reduce(min);

    return Column(
      children: [
        _Header(
          days: days,
          onPrevious: () => _shift(-count),
          onNext: () => _shift(count),
        ),
        const Divider(),
        Expanded(
          child: SingleChildScrollView(
            key: _grid,
            controller: _scroll,
            child: Column(
              children: [
                for (var hour = 0; hour < 24; hour++)
                  SizedBox(
                    key: hour == openingHour ? _openingHour : null,
                    height: max(
                      _hourHeight,
                      days.map((d) => at(d, hour).length).reduce(max) *
                              (_blockHeight + 2) +
                          4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HourLabel(hour: hour),
                        for (final day in days)
                          Expanded(
                            child: _HourCell(
                              day: day,
                              hour: hour,
                              posts: at(day, hour),
                              onDrop: (post) => _drop(post, day, hour),
                              onDragMove: _edgeScroll,
                            ),
                          ),
                        // Lines the columns up under the day names.
                        const SizedBox(width: _labelWidth),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final List<DateTime> days;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _Header({
    required this.days,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: _PageButton(
            icon: CupertinoIcons.chevron_left,
            tooltip: 'Earlier days',
            onPressed: onPrevious,
          ),
        ),
        for (final d in days)
          Expanded(
            child: Text(
              DateFormat('EEE d').format(d),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: DateUtils.isSameDay(d, now)
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        SizedBox(
          width: _labelWidth,
          child: _PageButton(
            icon: CupertinoIcons.chevron_right,
            tooltip: 'Later days',
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

/// Also a drop zone: holding a dragged post over it turns the page, so a post
/// can move to a day that isn't showing.
class _PageButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _PageButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<PostModel>(
      onWillAcceptWithDetails: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onPressed());
        return false;
      },
      builder: (context, _, _) => IconButton(
        iconSize: 16,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _HourLabel extends StatelessWidget {
  final int hour;

  const _HourLabel({required this.hour});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _labelWidth,
      child: Padding(
        padding: const EdgeInsets.only(top: 2, left: LemaTheme.s1),
        child: Text(
          '${hour.toString().padLeft(2, '0')}:00',
          style: TextStyle(
            fontSize: 11,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _HourCell extends StatelessWidget {
  final DateTime day;
  final int hour;
  final List<PostModel> posts;
  final ValueChanged<PostModel> onDrop;
  final ValueChanged<Offset> onDragMove;

  const _HourCell({
    required this.day,
    required this.hour,
    required this.posts,
    required this.onDrop,
    required this.onDragMove,
  });

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    return DragTarget<PostModel>(
      // A slot already gone can't be scheduled into.
      onWillAcceptWithDetails: (d) =>
          dropTime(day, hour, d.data.scheduledTime).isAfter(DateTime.now()),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) => Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? LemaTheme.accent.withValues(alpha: 0.15)
              : null,
          border: Border(top: BorderSide(color: line), left: BorderSide(color: line)),
        ),
        child: Column(
          children: [for (final p in posts) _Block(post: p, onDragMove: onDragMove)],
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final PostModel post;
  final ValueChanged<Offset> onDragMove;

  const _Block({required this.post, required this.onDragMove});

  @override
  Widget build(BuildContext context) {
    final status = post.postStatus;
    final scheme = Theme.of(context).colorScheme;
    final prefix = status == PostStatus.failed || status == PostStatus.draft
        ? '${postStatusLabel(post)} · '
        : '';
    final block = Semantics(
      label: '${postStatusLabel(post)}, ${post.platformInfo.name}, '
          '${DateFormat('EEEE h:mm a').format(post.scheduledTime)}, ${post.caption}',
      child: Container(
        height: _blockHeight,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: LemaTheme.s1),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(LemaTheme.radiusControl),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OnAirTick(post: post),
            Text(
              '$prefix${post.caption}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
    // Only posts still waiting to go out can move.
    if (status != PostStatus.scheduled && status != PostStatus.draft) return block;
    return LongPressDraggable<PostModel>(
      data: post,
      onDragUpdate: (d) => onDragMove(d.globalPosition),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 120, child: block),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: block),
      child: block,
    );
  }
}
