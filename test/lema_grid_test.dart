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
import 'package:lema/widgets/floating_tab_bar.dart';
import 'package:lema/widgets/lema_toast.dart';
import 'package:lema/widgets/morph_pill_menu.dart';
import 'package:lema/widgets/showcase_carousel.dart';

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

void _noop(int _) {}

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

  group('Morph pill menu (Slice 11)', () {
    MorphPillMenuSpec specFor(void Function() onPick) => MorphPillMenuSpec(
          title: 'Instagram Channel',
          subtitle: '3 of 8 posts',
          icon: CupertinoIcons.camera_fill,
          accent: const Color(0xFFF56040),
          items: [
            MorphPillMenuItem(
              icon: CupertinoIcons.camera_fill,
              label: 'Instagram only',
              detail: 'Reels, feed and carousels',
              onTap: onPick,
              selected: true,
            ),
            MorphPillMenuItem(
              icon: CupertinoIcons.play_rectangle_fill,
              label: 'Vertical video only',
              detail: '9:16 reels and Shorts',
              onTap: onPick,
            ),
          ],
        );

    Future<GlobalKey> pumpAnchor(WidgetTester tester) async {
      final anchor = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                key: anchor,
                width: 120,
                height: 40,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      return anchor;
    }

    testWidgets('opens from the pill rect, then dismisses on tap',
        (tester) async {
      var picked = false;
      final anchor = await pumpAnchor(tester);
      final ctx = tester.element(find.byKey(anchor));

      MorphPillMenu.show(ctx, anchorKey: anchor, spec: specFor(() => picked = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Instagram Channel'), findsOneWidget);
      expect(find.text('Instagram only'), findsOneWidget);
      expect(find.text('Vertical video only'), findsOneWidget);
      // Selected row shows a checkmark affordance.
      expect(find.byIcon(CupertinoIcons.checkmark_alt), findsOneWidget);

      await tester.tap(find.text('Instagram only'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(picked, isTrue);
      expect(find.text('Instagram Channel'), findsNothing);
    });

    testWidgets('scrim tap dismisses without firing an action',
        (tester) async {
      var picked = false;
      final anchor = await pumpAnchor(tester);
      final ctx = tester.element(find.byKey(anchor));

      MorphPillMenu.show(ctx, anchorKey: anchor, spec: specFor(() => picked = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Instagram Channel'), findsOneWidget);

      // Tap the scrim, top-left corner (away from the card).
      await tester.tapAt(const Offset(12, 12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Instagram Channel'), findsNothing);
      expect(picked, isFalse);
    });
  });

  group('Floating tab bar (Slice 12)', () {
    testWidgets('renders 5 tabs with poster reflections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloatingTabBar(currentIndex: 0, onTap: _noop),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // One mirror per tab = 10 icons (5 base + 5 reflections).
      expect(find.byType(Icon), findsNWidgets(10));
      // Every reflection is masked with a vertical alpha gradient.
      expect(find.byType(ShaderMask), findsNWidgets(5));
      for (final label in ['Lema', 'Simulator', 'Queue', 'Calendar', 'AI Studio']) {
        expect(find.text(label), findsOneWidget);
      }

      // Tab switch reports the tapped index.
      await tester.tap(find.text('Calendar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Calendar'), findsOneWidget);
    });
  });

  group('Intro showcase (Slice 13)', () {
    Future<void> pumpShowcase(WidgetTester tester) => tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ShowcaseCarousel(autoPlay: false)),
          ),
        );

    testWidgets('renders slide copy, styles, shutter and skip', (tester) async {
      await pumpShowcase(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Shoot once'), findsOneWidget);
      expect(find.text('Then let AI style it'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      // 3 style chips on the active slide.
      expect(find.text('Warm film'), findsOneWidget);
      expect(find.text('Neon night'), findsOneWidget);
    });

    testWidgets('shutter runs the shot and advances to slide 2',
        (tester) async {
      await pumpShowcase(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Shoot once'), findsOneWidget);

      // Tap the floating shutter (the last GestureDetector in the stack).
      await tester.tap(find.byKey(ShowcaseCarousel.shutterKey));
      await tester.pump();

      // Blur ramp: the styled frame is layered in with ImageFiltered.
      expect(find.byType(ImageFiltered), findsWidgets);

      // Complete the shot + the page transition.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Let AI style it'), findsOneWidget);
    });

    testWidgets('no overflow at 402pt and reduced-motion collapses the shot',
        (tester) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: ShowcaseCarousel(autoPlay: false)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(ShowcaseCarousel.shutterKey));
      await tester.pump(const Duration(seconds: 2));
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
