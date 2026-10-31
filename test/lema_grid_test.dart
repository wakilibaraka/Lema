import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/core/models/post_model.dart';
import 'package:lema/core/providers/app_provider.dart';
import 'package:lema/core/providers/auth_provider.dart';
import 'package:lema/core/providers/posts_provider.dart';
import 'package:lema/core/providers/profile_provider.dart';
import 'package:lema/core/services/api_service.dart';
import 'package:lema/core/services/demo_mode_service.dart';
import 'package:lema/core/services/storage_service.dart';
import 'package:lema/views/queue_view.dart';
import 'package:lema/views/settings_view.dart';
import 'package:lema/widgets/lema_toast.dart';
import 'package:lema/core/demo_seed.dart';

/// Slice 9: Lema grid logic + provider coverage.
///
/// Unit tests cover seeds, filters, reorder mapping, undo, CRUD and seed
/// migration. Widget tests pump the real grid (large surface so slivers
/// build without scrolling) and the toast. Explicit pumps are used instead
/// of pumpAndSettle because video tiles show a spinning loader while their
/// (expected-to-fail) decodes resolve in the test env.

PostModel _tPost(
  String id, {
  String status = 'scheduled',
  List<String> platforms = const ['instagram'],
  bool video = false,
}) {
  return PostModel(
    id: id,
    caption: 'Caption $id #test',
    platforms: platforms,
    mediaType: video ? 'video' : 'image',
    mediaUrl: video
        ? 'assets/samples/emms_story_features.mp4'
        : 'assets/samples/emms_post1_story30mins.png',
    scheduledTime: DateTime(2026, 10, 12, 9),
    status: status,
  );
}

Future<PostsProvider> _freshProvider(
    [Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  StorageService(prefs);
  final provider = PostsProvider();
  // Let the background backend sync fail fast and settle.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  return provider;
}

String _postsJson(List<PostModel> posts) =>
    jsonEncode(posts.map((p) => p.toJson()).toList());

void main() {
  group('Seeds & filters', () {
    test('default seeds load with scheduled/draft counts', () async {
      final provider = await _freshProvider();
      expect(provider.posts.length, 8);
      expect(provider.scheduledPosts.length, 5);
      expect(
          provider.posts.where((p) => p.status == 'draft').length, 3);
    });

    test('draft seeds are multi-platform for tile dots', () async {
      final provider = await _freshProvider();
      final drafts =
          provider.posts.where((p) => p.status == 'draft').toList();
      expect(drafts.any((p) => p.platforms.length > 1), isTrue);
      expect(drafts.any((p) => p.isVideo), isTrue);
      expect(drafts.any((p) => !p.isVideo), isTrue);
    });

    test('filterPostsByChannel narrows correctly', () async {
      final provider = await _freshProvider();
      expect(provider.filterPostsByChannel('all').length, 8);
      final tiktok = provider.filterPostsByChannel('tiktok');
      expect(tiktok, isNotEmpty);
      expect(tiktok.every((p) => p.platforms.contains('tiktok')), isTrue);
    });

    test('mutation guard: writes never corrupt the seed template', () async {
      final provider = await _freshProvider();
      provider.addPost(_tPost('x', status: 'draft'));
      provider.reorderPosts(0, 2, 'all', 'all', 'all');
      provider.deletePost('x');
      // A brand-new provider over empty storage must see pristine seeds.
      final fresh = await _freshProvider();
      expect(fresh.posts.length, 8);
      expect(fresh.posts.where((p) => p.status == 'draft').length, 3);
    });
  });

  group('Reorder mapping & undo', () {
    // Customs use status 'published' so the status filter isolates them
    // from merged seeds deterministically.
    List<PostModel> publishedFour() => [
          _tPost('a', status: 'published'),
          _tPost('b', status: 'published'),
          _tPost('c', status: 'published'),
          _tPost('d', status: 'published'),
        ];

    test('filtered reorder maps back onto the master queue', () async {
      final provider = await _freshProvider(
          {'lema_posts': _postsJson(publishedFour())});
      expect(provider.posts.take(4).map((p) => p.id).toList(),
          ['a', 'b', 'c', 'd']);
      expect(provider.canUndoReorder, isFalse);

      provider.reorderPosts(0, 2, 'all', 'published', 'all');
      expect(provider.posts.take(4).map((p) => p.id).toList(),
          ['b', 'a', 'c', 'd']);
      expect(provider.canUndoReorder, isTrue);

      provider.undoLastReorder();
      expect(provider.posts.take(4).map((p) => p.id).toList(),
          ['a', 'b', 'c', 'd']);
      expect(provider.canUndoReorder, isFalse);
    });

    test('out-of-range reorder is a no-op', () async {
      final provider = await _freshProvider(
          {'lema_posts': _postsJson(publishedFour())});
      provider.reorderPosts(0, 9, 'all', 'published', 'all');
      expect(provider.posts.take(4).map((p) => p.id).toList(),
          ['a', 'b', 'c', 'd']);
      expect(provider.canUndoReorder, isFalse);
    });
  });

  group('CRUD & migration', () {
    test('add/update/delete round-trip', () async {
      final provider = await _freshProvider(
          {'lema_posts': _postsJson([_tPost('a')])});
      provider.addPost(_tPost('n', status: 'draft'));
      expect(provider.posts.first.id, 'n');

      final updated = _tPost('n', status: 'scheduled').copyWith(
        caption: 'Edited',
        scheduledTime: DateTime(2026, 10, 20, 18, 30),
        scheduledDate: '2026-10-20',
        platforms: ['tiktok', 'youtube'],
      );
      provider.updatePost(updated);
      final fetched =
          provider.posts.firstWhere((p) => p.id == 'n');
      expect(fetched.caption, 'Edited');
      expect(fetched.scheduledTime,
          DateTime(2026, 10, 20, 18, 30));
      expect(fetched.platforms, ['tiktok', 'youtube']);

      provider.deletePost('n');
      expect(provider.posts.any((p) => p.id == 'n'), isFalse);
    });

    test('seed migration merges new drafts into stored posts', () async {
      final oldFive = defaultSeedPosts.take(5).toList();
      final provider = await _freshProvider(
          {'lema_posts': _postsJson(oldFive)});
      expect(provider.posts.length, 8);
      expect(provider.posts.any((p) => p.id == 'draft-1'), isTrue);
      expect(provider.posts.any((p) => p.id == 'draft-3'), isTrue);
    });

    test('corrupt stored JSON surfaces loadError; retry restores seeds',
        () async {
      final provider =
          await _freshProvider({'lema_posts': '[[corrupt'});
      expect(provider.loadError, isTrue);
      // Display still falls back to seeds (never a red screen).
      expect(provider.posts.length, 8);
      await provider.retryLoad();
      expect(provider.loadError, isFalse);
      expect(provider.posts.length, 8);
      expect(provider.canUndoReorder, isFalse);
    });
  });

  group('PostModel parsing', () {
    test('media type, likes and time passthrough', () {
      final video = _tPost('v', video: true);
      final image = _tPost('i');
      expect(video.isVideo, isTrue);
      expect(image.isVideo, isFalse);
      expect(_tPost('l').copyWith(likes: '2.8K').likesCount, 28);
      final dt = DateTime(2026, 11, 1, 7, 45);
      expect(_tPost('t').copyWith(scheduledTime: dt).scheduledTime,
          dt);
    });
  });

  group('Queue dispatch (Slice 18)', () {
    // NOTE: widget tests must NOT use _freshProvider — its real
    // Future.delayed deadlocks under testWidgets' fake async clock.
    Future<PostsProvider> pumpQueue(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      StorageService(prefs);
      final provider = PostsProvider();
      final app = AppProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: app),
              ChangeNotifierProvider.value(value: provider),
            ],
            child: const QueueView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      return provider;
    }

    testWidgets('compact header and segment pills render without overflow',
        (tester) async {
      await pumpQueue(tester);
      expect(tester.takeException(), isNull);

      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Scheduled (5)'), findsOneWidget);
      expect(find.text('Published (0)'), findsOneWidget);
      expect(find.text('Create Post'), findsOneWidget);
      // Queue item cards: badges, caption, asset, actions.
      expect(find.text('Share Now'), findsWidgets);
      expect(find.text('Remove'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('segment pills switch Scheduled and Published', (tester) async {
      await pumpQueue(tester);

      await tester.tap(find.text('Published (0)'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No Published Posts Yet'), findsOneWidget);

      await tester.tap(find.text('Scheduled (5)'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Share Now'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Share Now runs Sending then lands in Published (demo mode daemon)',
        (tester) async {
      // Demo mode stands in for the daemon, so the dispatch really is
      // reported as sent. Without it the mocked transport refuses and the
      // post must stay queued (covered in dispatch_truth_test.dart).
      await DemoModeService.setEnabled(true);
      addTearDown(() => DemoModeService.setEnabled(false));

      final provider = await pumpQueue(tester);
      expect(provider.scheduledPosts.length, 5);

      await tester.tap(find.text('Share Now').first);
      await tester.pump(const Duration(milliseconds: 150));
      // Sending state: spinner replaces the button.
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(provider.scheduledPosts.length, 4);
      expect(provider.publishedPosts.length, 1);
      // Demo mode reports its own label now and must never claim a daemon
      // send (review finding 1) — the old 'Dispatched to … via daemon'
      // text was the bug, not the contract.
      expect(
          find.textContaining('Demo mode: local publish simulated'),
          findsOneWidget);
      expect(find.textContaining('via daemon'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refused dispatch keeps the post queued and offers Retry',
        (tester) async {
      await DemoModeService.setEnabled(false);

      final provider = await pumpQueue(tester);
      expect(provider.scheduledPosts.length, 5);

      await tester.tap(find.text('Share Now').first);
      await tester.pump(const Duration(seconds: 2));

      // Nothing was published, so nothing may claim it was.
      expect(provider.scheduledPosts.length, 5);
      expect(provider.publishedPosts, isEmpty);
      expect(find.textContaining('Dispatched to'), findsNothing);
      expect(find.textContaining('Not sent'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Settings autoplay (Slice 22)', () {
    test('autoplay defaults off and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final storage =
          StorageService(await SharedPreferences.getInstance());
      expect(storage.autoplayVideos(), isFalse);

      final app = AppProvider(storage, const ApiService());
      expect(app.autoplayVideos, isFalse);

      app.toggleAutoplay();
      expect(app.autoplayVideos, isTrue);
      expect(storage.autoplayVideos(), isTrue);

      app.toggleAutoplay();
      expect(app.autoplayVideos, isFalse);
      expect(storage.autoplayVideos(), isFalse);
    });

    // NOTE: same fake-async rule — no real Future.delayed here.
    Future<StorageService> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);
      final app = AppProvider(storage, const ApiService());
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: app),
              ChangeNotifierProvider(create: (_) => ProfileProvider()),
              // SettingsView watches AuthProvider for the connected-
              // accounts card; omitting it threw ProviderNotFound and
              // masked the autoplay switch behind an error widget.
              ChangeNotifierProvider(create: (_) => AuthProvider()),
            ],
            child: const SettingsView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      return storage;
    }

    testWidgets('settings render without overflow at 402pt', (tester) async {
      await pumpSettings(tester);
      expect(tester.takeException(), isNull);

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Media Playback'), findsOneWidget);
      expect(find.text('Video autoplay'), findsOneWidget);
      expect(find.byKey(const ValueKey('autoplay_switch')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('autoplay switch flips and persists', (tester) async {
      final storage = await pumpSettings(tester);
      expect(storage.autoplayVideos(), isFalse);

      final sw = find.byKey(const ValueKey('autoplay_switch'));
      await tester.ensureVisible(sw);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(sw);
      await tester.pump(const Duration(milliseconds: 300));
      expect(storage.autoplayVideos(), isTrue);

      await tester.tap(sw);
      await tester.pump(const Duration(milliseconds: 300));
      expect(storage.autoplayVideos(), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Lema toast', () {
    testWidgets('Moved toast shows Undo and fires callback',
        (tester) async {
      var undone = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => CupertinoButton(
                onPressed: () => LemaToast.show(
                  context,
                  'Moved to position 2 of 8',
                  kind: LemaToastKind.moved,
                  actionLabel: 'Undo',
                  onAction: () => undone = true,
                ),
                child: const Text('Trigger'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Moved to position 2 of 8'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Undo'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(undone, isTrue);
    });
  });
}
