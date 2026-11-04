import '../../core/models/post_model.dart';
import '../../core/services/analytics_service.dart';

/// One published post with its numbers resolved. Everything below is a pure
/// function of these rows, so the screen holds no arithmetic.
class PostMetric {
  final String id;
  final String title;
  final String platform;
  final DateTime at;
  final int views;
  final int engagements;

  const PostMetric({
    required this.id,
    required this.title,
    required this.platform,
    required this.at,
    required this.views,
    required this.engagements,
  });

  double get rate => views > 0 ? engagements / views : 0;
}

/// Pairs posts with their analytics by id. A post with no row counts as zero.
List<PostMetric> buildMetrics(
    List<PostModel> posts, Map<String, PostAnalytics> byId) {
  return [
    for (final post in posts)
      PostMetric(
        id: post.id,
        title: post.title,
        platform: post.primaryPlatform.name,
        at: post.postedAt ?? post.scheduledTime,
        views: byId[post.id]?.views ?? 0,
        engagements: (byId[post.id]?.likes ?? 0) +
            (byId[post.id]?.comments ?? 0) +
            (byId[post.id]?.shares ?? 0),
      ),
  ];
}

// Calendar arithmetic, so a daylight-saving change can't shift a boundary.
DateTime _dayStart(DateTime now, int daysAgo) =>
    DateTime(now.year, now.month, now.day - daysAgo);

/// Rows in the [days]-long window ending today, or the window before it when
/// [previous] is true.
List<PostMetric> inPeriod(List<PostMetric> rows, DateTime now, int days,
    {bool previous = false}) {
  final start = _dayStart(now, previous ? days * 2 - 1 : days - 1);
  final end = _dayStart(now, previous ? days - 1 : -1);
  return rows.where((r) => !r.at.isBefore(start) && r.at.isBefore(end)).toList();
}

class PeriodSummary {
  final int reach;
  final int engagements;
  final int posts;

  const PeriodSummary(this.reach, this.engagements, this.posts);

  factory PeriodSummary.of(List<PostMetric> rows) => PeriodSummary(
        rows.fold(0, (sum, r) => sum + r.views),
        rows.fold(0, (sum, r) => sum + r.engagements),
        rows.length,
      );

  /// Weighted by views, so a tiny post can't swing it.
  double get rate => reach > 0 ? engagements / reach : 0;
}

/// Percent change, or null when there is nothing to compare against.
double? percentChange(num current, num previous) =>
    previous > 0 ? (current - previous) / previous * 100 : null;

class TrendPoint {
  final DateTime start;
  final DateTime end; // inclusive last day
  final int reach;

  const TrendPoint(this.start, this.end, this.reach);
}

/// Reach over the window in [points] equal buckets, oldest first. Posts land
/// every few days, so single-day points would saw between peaks and zero.
List<TrendPoint> reachTrend(List<PostMetric> rows, DateTime now, int days,
    {int points = 10}) {
  final size = days ~/ points;
  return [
    for (var i = points - 1; i >= 0; i--)
      () {
        final start = _dayStart(now, size * (i + 1) - 1);
        final next = _dayStart(now, size * i - 1);
        return TrendPoint(
          start,
          _dayStart(now, size * i),
          rows
              .where((r) => !r.at.isBefore(start) && r.at.isBefore(next))
              .fold(0, (sum, r) => sum + r.views),
        );
      }(),
  ];
}

/// Highest engagement rate first; posts with no views can't be ranked.
List<PostMetric> topPosts(List<PostMetric> rows, {int limit = 5}) {
  final ranked = rows.where((r) => r.views > 0).toList()
    ..sort((a, b) => b.rate.compareTo(a.rate));
  return ranked.take(limit).toList();
}

/// Reach per platform, largest first.
List<MapEntry<String, int>> platformReach(List<PostMetric> rows) {
  final totals = <String, int>{};
  for (final r in rows) {
    totals[r.platform] = (totals[r.platform] ?? 0) + r.views;
  }
  return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

/// Hours of the day (0-23) with the best average engagement rate, best first.
List<int> bestHours(List<PostMetric> rows, {int limit = 3}) {
  final rates = <int, List<double>>{};
  for (final r in rows.where((r) => r.views > 0)) {
    rates.putIfAbsent(r.at.hour, () => []).add(r.rate);
  }
  double average(List<double> v) => v.reduce((a, b) => a + b) / v.length;
  final hours = rates.keys.toList()
    ..sort((a, b) => average(rates[b]!).compareTo(average(rates[a]!)));
  return hours.take(limit).toList();
}
