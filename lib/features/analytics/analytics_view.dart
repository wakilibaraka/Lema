import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/platform_info.dart';
import '../../core/providers/posts_provider.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme.dart';
import 'metrics.dart';
import 'trend_chart.dart';

const _tabular = [FontFeature.tabularFigures()];

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  AnalyticsResult? _result;
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final posts = context.read<PostsProvider>().publishedPosts;
    final result = await AnalyticsService.instance.fetchAggregatedAnalytics(posts);
    if (mounted) {
      setState(() {
        _result = result;
        _loading = false;
      });
    }
  }

  /// The fetch covers a snapshot of the published set, so a post published or
  /// removed afterwards would otherwise wait for a manual refresh.
  void _reloadIfPublishedSetChanged(int publishedCount) {
    if (_loading || _result == null) return;
    if (_result!.perPost.length == publishedCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final published = context.watch<PostsProvider>().publishedPosts;
    _reloadIfPublishedSetChanged(published.length);

    if (_loading) return const Center(child: CupertinoActivityIndicator());
    if (_result == null || published.isEmpty) {
      return const Center(child: Text('No published posts yet'));
    }

    final now = DateTime.now();
    final rows = buildMetrics(published, _result!.byPostId);
    final current = inPeriod(rows, now, _days);
    final previous = inPeriod(rows, now, _days, previous: true);

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 800;
      final edge = wide ? LemaTheme.s6 : LemaTheme.s4;
      final top = _TopPosts(rows: topPosts(current));
      final share = _PlatformShare(entries: platformReach(current));
      return ListView(
        padding: EdgeInsets.all(edge),
        children: [
          _Header(
            days: _days,
            onDays: (d) => setState(() => _days = d),
            onRefresh: _loadAnalytics,
          ),
          const SizedBox(height: LemaTheme.s4),
          _StatGrid(
            columns: wide ? 4 : 2,
            days: _days,
            current: PeriodSummary.of(current),
            previous: PeriodSummary.of(previous),
            bestHour: bestHours(current).firstOrNull,
          ),
          const SizedBox(height: LemaTheme.s4),
          _Panel(
            title: 'Reach',
            child: TrendChart(points: reachTrend(rows, now, _days)),
          ),
          const SizedBox(height: LemaTheme.s4),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: top),
                const SizedBox(width: LemaTheme.s4),
                Expanded(flex: 2, child: share),
              ],
            )
          else ...[
            top,
            const SizedBox(height: LemaTheme.s4),
            share,
          ],
        ],
      );
    });
  }
}

class _Header extends StatelessWidget {
  final int days;
  final ValueChanged<int> onDays;
  final VoidCallback onRefresh;

  const _Header(
      {required this.days, required this.onDays, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('Last $days days',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        ),
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 30, label: Text('30d')),
            ButtonSegment(value: 90, label: Text('90d')),
          ],
          selected: {days},
          onSelectionChanged: (s) => onDays(s.first),
        ),
        IconButton(
          tooltip: 'Refresh',
          iconSize: 18,
          onPressed: onRefresh,
          icon: const Icon(CupertinoIcons.refresh),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final int columns;
  final int days;
  final PeriodSummary current;
  final PeriodSummary previous;
  final int? bestHour;

  const _StatGrid({
    required this.columns,
    required this.days,
    required this.current,
    required this.previous,
    required this.bestHour,
  });

  String _vs(double? percent) {
    if (percent == null) return 'No earlier data to compare';
    final sign = percent >= 0 ? '+' : '';
    return '$sign${percent.toStringAsFixed(0)}% vs previous $days days';
  }

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compact();
    final points = (current.rate - previous.rate) * 100;
    final cards = [
      _StatCard(
        label: 'Reach',
        value: compact.format(current.reach),
        note: _vs(percentChange(current.reach, previous.reach)),
      ),
      _StatCard(
        label: 'Engagement rate',
        value: '${(current.rate * 100).toStringAsFixed(1)}%',
        note: previous.reach == 0
            ? 'No earlier data to compare'
            : '${points >= 0 ? '+' : ''}${points.toStringAsFixed(1)} pts vs previous $days days',
      ),
      _StatCard(
        label: 'Posts published',
        value: '${current.posts}',
        note: _vs(percentChange(current.posts, previous.posts)),
      ),
      _StatCard(
        label: 'Best time',
        value: bestHour == null
            ? '–'
            : DateFormat.j().format(DateTime(2000, 1, 1, bestHour!)),
        note: 'Highest average engagement',
      ),
    ];
    return LayoutBuilder(builder: (context, box) {
      final width =
          (box.maxWidth - LemaTheme.s3 * (columns - 1)) / columns;
      return Wrap(
        spacing: LemaTheme.s3,
        runSpacing: LemaTheme.s3,
        children: [for (final c in cards) SizedBox(width: width, child: c)],
      );
    });
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String note;

  const _StatCard({required this.label, required this.value, required this.note});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LemaTheme.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: muted)),
            const SizedBox(height: LemaTheme.s2),
            Text(value,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    fontFeatures: _tabular)),
            const SizedBox(height: LemaTheme.s1),
            // Two lines reserved so neighbouring cards stay the same height.
            SizedBox(
              height: 32,
              child: Text(note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LemaTheme.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: LemaTheme.s4),
            child,
          ],
        ),
      ),
    );
  }
}

class _TopPosts extends StatelessWidget {
  final List<PostMetric> rows;

  const _TopPosts({required this.rows});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final compact = NumberFormat.compact();
    return _Panel(
      title: 'Top posts by engagement rate',
      child: rows.isEmpty
          ? Text('Nothing published in this period',
              style: TextStyle(fontSize: 13, color: muted))
          : Column(
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: LemaTheme.s2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                              Text(
                                  '${_platformName(r.platform)} · ${compact.format(r.views)} views',
                                  style: TextStyle(fontSize: 12, color: muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: LemaTheme.s3),
                        Text('${(r.rate * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFeatures: _tabular)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PlatformShare extends StatelessWidget {
  final List<MapEntry<String, int>> entries;

  const _PlatformShare({required this.entries});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    return _Panel(
      title: 'Reach by platform',
      child: entries.isEmpty
          ? Text('Nothing published in this period',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))
          : Column(
              children: [
                for (final e in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: LemaTheme.s2),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_platformName(e.key),
                                style: const TextStyle(fontSize: 13)),
                            Text(
                                total == 0
                                    ? '0%'
                                    : '${(e.value / total * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 13, fontFeatures: _tabular)),
                          ],
                        ),
                        const SizedBox(height: LemaTheme.s1),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : e.value / total,
                            minHeight: 4,
                            color: scheme.primary,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

String _platformName(String id) => platformsMap[id]?.name ?? id;
