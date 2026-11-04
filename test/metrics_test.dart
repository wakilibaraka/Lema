import 'package:flutter_test/flutter_test.dart';
import 'package:lema/core/models/post_model.dart';
import 'package:lema/core/services/analytics_service.dart';
import 'package:lema/features/analytics/metrics.dart';

final now = DateTime(2026, 11, 4, 12);

PostMetric row(String id, int daysAgo,
        {int views = 100, int eng = 10, String platform = 'instagram', int hour = 9}) =>
    PostMetric(
      id: id,
      title: id,
      platform: platform,
      at: DateTime(now.year, now.month, now.day - daysAgo, hour),
      views: views,
      engagements: eng,
    );

void main() {
  test('periods split at the boundary with no overlap', () {
    final rows = [row('today', 0), row('edge', 29), row('prev', 30), row('prevEdge', 59), row('old', 60)];
    expect(inPeriod(rows, now, 30).map((r) => r.id), ['today', 'edge']);
    expect(inPeriod(rows, now, 30, previous: true).map((r) => r.id),
        ['prev', 'prevEdge']);
  });

  test('summary rate is weighted by views and safe at zero', () {
    final s = PeriodSummary.of([row('a', 0, views: 900, eng: 90), row('b', 0, views: 100, eng: 50)]);
    expect(s.reach, 1000);
    expect(s.rate, closeTo(0.14, 1e-9));
    expect(PeriodSummary.of([]).rate, 0);
  });

  test('percent change has no answer without a baseline', () {
    expect(percentChange(150, 100), 50);
    expect(percentChange(10, 0), isNull);
  });

  test('trend buckets cover every view exactly once, oldest first', () {
    final rows = [row('a', 0, views: 1), row('b', 2, views: 2), row('c', 3, views: 4), row('d', 29, views: 8)];
    final trend = reachTrend(rows, now, 30);
    expect(trend.length, 10);
    expect(trend.last.reach, 3);
    expect(trend[8].reach, 4);
    expect(trend.first.reach, 8);
    expect(trend.first.start, DateTime(2026, 10, 6));
  });

  test('top posts rank by rate and skip zero views', () {
    final top = topPosts([
      row('low', 0, eng: 1),
      row('high', 0, eng: 50),
      row('none', 0, views: 0, eng: 5),
    ]);
    expect(top.map((r) => r.id), ['high', 'low']);
  });

  test('platform reach sums and sorts', () {
    final p = platformReach([
      row('a', 0, platform: 'tiktok', views: 10),
      row('b', 0, platform: 'instagram', views: 30),
      row('c', 0, platform: 'tiktok', views: 5),
    ]);
    expect(p.map((e) => e.key), ['instagram', 'tiktok']);
    expect(p.last.value, 15);
  });

  test('best hours average per hour', () {
    final hours = bestHours([
      row('a', 0, hour: 9, eng: 10),
      row('b', 1, hour: 9, eng: 30),
      row('c', 0, hour: 18, eng: 25),
      row('d', 0, hour: 7, eng: 5),
    ], limit: 2);
    expect(hours, [18, 9]);
  });

  test('buildMetrics pairs by id and counts a missing row as zero', () {
    final post = PostModel(id: 'p', caption: 'c', mediaUrl: 'x.png', status: 'published');
    final other = PostModel(id: 'q', caption: 'c', mediaUrl: 'x.png', status: 'published');
    final rows = buildMetrics([post, other], {
      'p': PostAnalytics(postId: 'p', platform: 'instagram', views: 10, likes: 1, comments: 2, shares: 3),
    });
    expect(rows.first.engagements, 6);
    expect(rows.last.views, 0);
  });
}
