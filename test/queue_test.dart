import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/core/models/post_model.dart';
import 'package:lema/core/models/queue_slot_model.dart';
import 'package:lema/core/providers/posts_provider.dart';
import 'package:lema/core/recurrence.dart';
import 'package:lema/core/services/api_service.dart';
import 'package:lema/core/services/queue_autofill_service.dart';
import 'package:lema/core/services/storage_service.dart';

class _StubApi extends ApiService {
  final DispatchResult result;
  const _StubApi(this.result);

  @override
  Future<DispatchResult> dispatchPost(PostModel post) async => result;

  @override
  Future<List<PostModel>> fetchQueue() async => [];
}

PostModel _post(String id, DateTime at,
        {String recurrence = recurrenceNone, List<int> days = const []}) =>
    PostModel(
      id: id,
      caption: id,
      mediaUrl: 'a.png',
      scheduledTime: at,
      recurrence: recurrence,
      recurrenceDays: days,
    );

Future<StorageService> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return StorageService(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nextOccurrence', () {
    final monday9 = DateTime(2026, 11, 2, 9);

    test('a one-off post has none', () {
      expect(nextOccurrence(_post('p', monday9), monday9), isNull);
    });

    test('daily keeps the time and skips missed days', () {
      final p = _post('p', monday9, recurrence: recurrenceDaily);
      expect(nextOccurrence(p, monday9), DateTime(2026, 11, 3, 9));
      expect(nextOccurrence(p, DateTime(2026, 11, 20, 10)), DateTime(2026, 11, 21, 9));
    });

    test('weekly lands on the picked weekdays', () {
      final p = _post('p', monday9,
          recurrence: recurrenceWeekly, days: [DateTime.friday]);
      expect(nextOccurrence(p, monday9), DateTime(2026, 11, 6, 9));
    });

    test('weekly with no days repeats on the scheduled weekday', () {
      final p = _post('p', monday9, recurrence: recurrenceWeekly);
      expect(nextOccurrence(p, monday9), DateTime(2026, 11, 9, 9));
    });
  });

  group('openSlotTimes', () {
    final now = DateTime(2026, 11, 2, 10);
    const slots = [QueueSlotModel(id: 's', time: '01:15 PM', label: 'Lunch')];

    test('uses the best hour that is still ahead, and skips busy days', () {
      final times = QueueAutofillService.openSlotTimes(
        now: now,
        count: 2,
        scheduledPosts: [_post('busy', DateTime(2026, 11, 3, 8))],
        rankedHours: const [9, 18],
        fallbackSlots: slots,
      );
      expect(times, [DateTime(2026, 11, 2, 18), DateTime(2026, 11, 4, 9)]);
    });

    test('falls back to the seed slots with no history', () {
      final times = QueueAutofillService.openSlotTimes(
        now: now,
        count: 1,
        scheduledPosts: const [],
        rankedHours: const [],
        fallbackSlots: slots,
      );
      expect(times, [DateTime(2026, 11, 2, 13, 15)]);
    });
  });

  group('PostsProvider queue', () {
    test('a failure and its reason survive a reload; a retry clears them',
        () async {
      final storage = await _storage();
      final failing = PostsProvider(storage,
          const _StubApi(DispatchResult(DispatchOutcome.rejected, 'HTTP 422')));
      await failing.publishNow('post-1');

      final reloaded = PostsProvider(
          storage, const _StubApi(DispatchResult(DispatchOutcome.sent)));
      final saved = reloaded.failedPosts.single;
      expect(saved.id, 'post-1');
      expect(saved.failureReason, 'HTTP 422');

      await reloaded.publishNow('post-1');
      final sent = reloaded.posts.firstWhere((p) => p.id == 'post-1');
      expect(sent.status, 'published');
      expect(sent.failureReason, isNull);
    });

    test('publishing a repeating post queues the next one once', () async {
      final provider = PostsProvider(await _storage(),
          const _StubApi(DispatchResult(DispatchOutcome.sent)));
      final at = DateTime.now().add(const Duration(hours: 1));
      provider.addPost(_post('rep', at, recurrence: recurrenceDaily));

      await provider.publishNow('rep');

      final next = provider.queuePosts.where((p) => p.id.startsWith('rep-')).single;
      expect(next.recurrence, recurrenceDaily);
      expect(next.scheduledTime.isAfter(at), isTrue);
      expect(next.postedAt, isNull);
    });

    test('a failed repeating post does not queue the next one', () async {
      final provider = PostsProvider(await _storage(),
          const _StubApi(DispatchResult(DispatchOutcome.offline)));
      provider.addPost(_post('rep', DateTime.now(), recurrence: recurrenceDaily));

      await provider.publishNow('rep');

      expect(provider.posts.where((p) => p.id.startsWith('rep-')), isEmpty);
    });

    test('reorder keeps the slot times and undo restores them', () async {
      final provider = PostsProvider(await _storage(),
          const _StubApi(DispatchResult(DispatchOutcome.offline)));
      final before = provider.queuePosts;
      final times = before.map((p) => p.scheduledTime).toList();

      provider.reorderQueue(0, 1);

      final after = provider.queuePosts;
      expect(after.map((p) => p.scheduledTime), times);
      expect(after[0].id, before[1].id);
      expect(after[1].id, before[0].id);

      provider.undoLastReorder();
      expect(provider.queuePosts.map((p) => p.id), before.map((p) => p.id));
    });

    test('auto-slot schedules every draft on its own open day', () async {
      final provider = PostsProvider(await _storage(),
          const _StubApi(DispatchResult(DispatchOutcome.offline)));
      final drafts = provider.draftPosts.length;

      expect(provider.autoSlotDrafts(const [9]), drafts);
      expect(provider.draftPosts, isEmpty);

      provider.undoLastReorder();
      expect(provider.draftPosts.length, drafts);
    });
  });

  test('expiredChannels names every expired channel on the post', () {
    final post = PostModel(
      id: 'p',
      caption: 'c',
      mediaUrl: 'a.png',
      platforms: const ['instagram', 'tiktok', 'youtube'],
    );
    expect(post.expiredChannels(const ['tiktok', 'instagram', 'linkedin']),
        ['Instagram', 'TikTok']);
  });
}
