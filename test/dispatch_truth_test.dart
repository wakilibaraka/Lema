import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/models/post_model.dart';
import 'package:lema/providers/posts_provider.dart';
import 'package:lema/services/analytics_service.dart';
import 'package:lema/services/api_service.dart';
import 'package:lema/services/demo_mode_service.dart';
import 'package:lema/services/storage_service.dart';

/// Pins the difference between "the daemon took it" and "nothing happened".
///
/// `publishNow` used to flip a post to `published` before the request and
/// discard the boolean result, so the queue emptied even when no daemon was
/// listening and the Failed → Retry UI was unreachable.

/// Stands in for the transport so each outcome is deterministic in tests
/// (the real client cannot be told to refuse on demand).
class _StubApi extends ApiService {
  final DispatchResult result;
  int calls = 0;

  _StubApi(this.result);

  @override
  Future<DispatchResult> dispatchPost(PostModel post) async {
    calls++;
    return result;
  }
}

Future<StorageService> _storage([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return StorageService(prefs);
}

PostModel _post(
  String id, {
  String status = 'scheduled',
  dynamic scheduledTime,
  String scheduledDate = '2026-10-12',
}) {
  return PostModel(
    id: id,
    caption: 'Caption $id',
    mediaUrl: 'assets/samples/emms_post1_story30mins.png',
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime ?? '09:00',
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Registers the mock preference channel up front so the demo-mode reset in
  // tearDown never reaches a real platform implementation.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() => DemoModeService.setEnabled(false));

  group('Schedule time survives persistence', () {
    test('a DateTime schedule round-trips exactly through toJson/fromJson',
        () {
      final original = _post('p1', scheduledTime: DateTime(2026, 11, 3, 17, 45));
      final restored = PostModel.fromJson(original.toJson());

      expect(restored.scheduledTime, original.scheduledTime);
      expect(restored.scheduledDate, '2026-11-03');
      // The old parser treated the ISO stamp as "HH:MM", threw, and fell
      // back to now + 3h — so every restart silently rebased the queue.
      expect(
        restored.scheduledTime.isAfter(DateTime(2027)),
        isFalse,
        reason: 'a 2026 schedule must not be rebased into the future',
      );
    });

    test('legacy HH:MM payload still resolves against its stored date', () {
      final legacy = _post('p2',
          scheduledTime: '07:15', scheduledDate: '2026-10-20');
      final restored = PostModel.fromJson(legacy.toJson());

      expect(restored.scheduledTime, DateTime(2026, 10, 20, 7, 15));
    });

    test('updating only the time keeps the stored day in step', () {
      final post = _post('p3', scheduledTime: DateTime(2026, 10, 12, 9));
      final moved = post.copyWith(scheduledTime: DateTime(2026, 10, 19, 6, 30));

      expect(moved.scheduledDate, '2026-10-19');
      expect(moved.scheduledTime, DateTime(2026, 10, 19, 6, 30));
    });

    test('unreadable payload falls back to its own date, never to "now"', () {
      final broken = PostModel.fromJson({
        ..._post('p4').toJson(),
        'scheduledTime': 'not-a-time',
        'scheduledDate': '2026-10-12',
      });

      expect(broken.scheduledTime, DateTime(2026, 10, 12));
    });
  });

  group('publishNow reports what actually happened', () {
    test('an offline daemon leaves the post scheduled', () async {
      final storage = await _storage();
      final api = _StubApi(
          const DispatchResult(DispatchOutcome.offline, 'Daemon unreachable'));
      final provider = PostsProvider(storage, api);

      final result = await provider.publishNow('post-1');

      expect(result.outcome, DispatchOutcome.offline);
      expect(result.isSent, isFalse);
      expect(api.calls, 1);
      expect(
        provider.posts.firstWhere((p) => p.id == 'post-1').status,
        'scheduled',
      );
      expect(provider.publishedPosts, isEmpty);
    });

    test('a refusal is reported as rejected and not published', () async {
      final storage = await _storage();
      final api = _StubApi(
          const DispatchResult(DispatchOutcome.rejected, 'HTTP 422'));
      final provider = PostsProvider(storage, api);

      final result = await provider.publishNow('post-1');

      expect(result.outcome, DispatchOutcome.rejected);
      expect(result.toString(), 'HTTP 422');
      expect(
        provider.posts.firstWhere((p) => p.id == 'post-1').status,
        'scheduled',
      );
    });

    test('a sent dispatch publishes the post and stamps postedAt', () async {
      final storage = await _storage();
      final api = _StubApi(const DispatchResult(DispatchOutcome.sent));
      final provider = PostsProvider(storage, api);

      final result = await provider.publishNow('post-1');

      expect(result.isSent, isTrue);
      final post = provider.posts.firstWhere((p) => p.id == 'post-1');
      expect(post.status, 'published');
      expect(post.postedAt, isNotNull);
      expect(provider.publishedPosts.length, 1);
    });

    test('an unknown post id is reported, not silently ignored', () async {
      final storage = await _storage();
      final provider = PostsProvider(storage, _StubApi(
          const DispatchResult(DispatchOutcome.sent)));

      final result = await provider.publishNow('does-not-exist');

      expect(result.outcome, DispatchOutcome.rejected);
      expect(result.toString(), contains('no longer exists'));
    });
  });

  group('Overdue posts are surfaced', () {
    test('only past, still-scheduled posts count as overdue', () async {
      final storage = await _storage();
      final provider = PostsProvider(storage, _StubApi(
          const DispatchResult(DispatchOutcome.offline)));

      final past = DateTime.now().subtract(const Duration(hours: 2));
      final future = DateTime.now().add(const Duration(hours: 2));
      provider.addPost(_post('late', scheduledTime: past));
      provider.addPost(_post('soon', scheduledTime: future));
      provider.addPost(_post('done', status: 'published', scheduledTime: past));

      final ids = provider.overduePosts.map((p) => p.id).toList();

      expect(ids, ['late']);
      expect(provider.posts.firstWhere((p) => p.id == 'late').isOverdue, isTrue);
      expect(provider.posts.firstWhere((p) => p.id == 'soon').isOverdue, isFalse);
      expect(
        provider.posts.firstWhere((p) => p.id == 'done').isOverdue,
        isFalse,
        reason: 'published posts are done, not overdue',
      );
    });
  });

  group('Analytics pairing', () {
    test('rows are matched by post id, not list position', () {
      final result = AnalyticsResult(
        perPost: [
          PostAnalytics(postId: 'post-9', platform: 'tiktok', likes: 99),
          PostAnalytics(postId: 'post-2', platform: 'instagram', likes: 5),
        ],
      );

      expect(result.forPost('post-2')!.likes, 5);
      expect(result.forPost('post-9')!.likes, 99);
      expect(result.forPost('missing'), isNull);
    });

    test('compact counters parse to their real magnitude', () {
      expect(AnalyticsService.parseCompactCount('84.2K'), 84200);
      expect(AnalyticsService.parseCompactCount('1.2M'), 1200000);
      expect(AnalyticsService.parseCompactCount('1,240'), 1240);
      expect(AnalyticsService.parseCompactCount('2818'), 2818);
      expect(AnalyticsService.parseCompactCount(''), 0);
    });
  });

  group('Demo mode stands in for the daemon', () {
    test('dispatch succeeds locally and says so', () async {
      await DemoModeService.setEnabled(true);

      final result = await const ApiService().dispatchPost(_post('demo'));

      expect(result.outcome, DispatchOutcome.sent);
      expect(result.toString(), contains('Demo mode'));
    });
  });
}
