import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/models/post_model.dart';
import 'package:lema/providers/posts_provider.dart';
import 'package:lema/services/storage_service.dart';
import 'package:lema/views/lema_grid_view.dart';
import 'package:lema/widgets/lema_toast.dart';

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

  group('Lema grid widgets', () {
    Future<void> pumpGrid(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 6000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      StorageService(prefs);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => PostsProvider(),
            child: const LemaGridView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('header, pills, tiles and timeline render', (tester) async {
      await pumpGrid(tester);
      expect(find.text('LEMA'), findsOneWidget);
      expect(find.text('FEED GRID · DRAG TO REORDER'), findsOneWidget);
      // 5 scheduled tiles carry QUEUED pills.
      expect(find.text('QUEUED'), findsWidgets);
      // Density toggle labels ('3' also appears as the drafts stat).
      expect(find.text('3'), findsNWidgets(2));
      expect(find.text('4'), findsOneWidget);
      // Timeline section below the grid.
      expect(find.text("Today's timeline"), findsOneWidget);
    });

    testWidgets('Drafts filter narrows grid to draft tiles', (tester) async {
      await pumpGrid(tester);
      // Huge test surface lays out all slivers; ensureVisible scrolls the
      // chip into the hit-testable viewport (bare taps miss off-screen).
      await tester.ensureVisible(find.text('Drafts'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Drafts'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('DRAFT'), findsNWidgets(3));
      expect(find.text('QUEUED'), findsNothing);
    });

    testWidgets('decode failure shows error card; retry clears it',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues(
          {'lema_posts': '[[corrupt'});
      final prefs = await SharedPreferences.getInstance();
      StorageService(prefs);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => PostsProvider(),
            child: const LemaGridView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text("Couldn't load your queue"), findsOneWidget);
      expect(find.text('QUEUED'), findsNothing);
      await tester.ensureVisible(find.text('Reset to starter posts'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Reset to starter posts'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text("Couldn't load your queue"), findsNothing);
      expect(find.text('QUEUED'), findsWidgets);
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
