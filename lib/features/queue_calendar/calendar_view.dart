import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/models/post_model.dart';
import '../../core/providers/posts_provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/on_air_tick.dart';
import 'week_view.dart';

/// The same posts laid out in time, as a month or as an hour grid.
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  bool _week = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              LemaTheme.s4, LemaTheme.s4, LemaTheme.s4, LemaTheme.s3),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Month')),
                ButtonSegment(value: true, label: Text('Week')),
              ],
              selected: {_week},
              onSelectionChanged: (s) => setState(() => _week = s.first),
            ),
          ),
        ),
        Expanded(child: _week ? const WeekView() : const _MonthView()),
      ],
    );
  }
}

class _MonthView extends StatefulWidget {
  const _MonthView();

  @override
  State<_MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<_MonthView> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<PostsProvider>().posts;
    List<PostModel> on(DateTime day) =>
        posts.where((p) => isSameDay(p.scheduledTime, day)).toList()
          ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    final month = Card(
      child: Padding(
        padding: const EdgeInsets.all(LemaTheme.s3),
        child: TableCalendar<PostModel>(
          firstDay: DateTime.utc(2025, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focused,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (day) => isSameDay(_selected, day),
          eventLoader: on,
          headerStyle: const HeaderStyle(titleCentered: true),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            todayDecoration: BoxDecoration(
              color: LemaTheme.accent.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            selectedDecoration: const BoxDecoration(
              color: LemaTheme.accentInk,
              shape: BoxShape.circle,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) => events.isEmpty
                ? null
                : Positioned(
                    bottom: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final p in events.take(4)) _Marker(post: p),
                      ],
                    ),
                  ),
          ),
          onDaySelected: (selected, focused) => setState(() {
            _selected = selected;
            _focused = focused;
          }),
          onPageChanged: (focused) => _focused = focused,
        ),
      ),
    );

    final day = on(_selected);
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DateFormat('EEEE, MMM d').format(_selected),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: LemaTheme.s3),
        if (day.isEmpty)
          Text(
            'Nothing on this day.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        for (final p in day) _DayRow(post: p),
      ],
    );

    const pad = EdgeInsets.fromLTRB(LemaTheme.s4, 0, LemaTheme.s4, LemaTheme.s8);
    if (MediaQuery.sizeOf(context).width < 900) {
      return ListView(
        padding: pad,
        children: [month, const SizedBox(height: LemaTheme.s5), list],
      );
    }
    return Padding(
      padding: pad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: SingleChildScrollView(child: month)),
          const SizedBox(width: LemaTheme.s6),
          Expanded(flex: 2, child: SingleChildScrollView(child: list)),
        ],
      ),
    );
  }
}

/// Platform colour for identity; the shape carries status, so it isn't
/// colour alone: failed is square, draft hollow, published faded.
class _Marker extends StatelessWidget {
  final PostModel post;

  const _Marker({required this.post});

  @override
  Widget build(BuildContext context) {
    final color = post.platformInfo.color;
    final status = post.postStatus;
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        shape: status == PostStatus.failed ? BoxShape.rectangle : BoxShape.circle,
        color: switch (status) {
          PostStatus.failed => LemaTheme.danger,
          PostStatus.draft => null,
          PostStatus.published => color.withValues(alpha: 0.45),
          PostStatus.scheduled => color,
        },
        border: status == PostStatus.draft ? Border.all(color: color) : null,
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final PostModel post;

  const _DayRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: LemaTheme.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnAirTick(post: post),
          const SizedBox(width: LemaTheme.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${postStatusLabel(post)} · ${post.platformInfo.name}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
