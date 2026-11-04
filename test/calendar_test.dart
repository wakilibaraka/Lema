import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/core/models/post_model.dart';
import 'package:lema/core/providers/posts_provider.dart';
import 'package:lema/core/services/storage_service.dart';
import 'package:lema/features/queue_calendar/calendar_view.dart';
import 'package:lema/features/queue_calendar/week_view.dart';

void main() {
  test('dropTime changes the day and hour and keeps the minutes', () {
    expect(dropTime(DateTime(2026, 11, 9), 14, DateTime(2026, 11, 4, 19, 50)),
        DateTime(2026, 11, 9, 14, 50));
  });

  Future<PostsProvider> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final posts = PostsProvider(StorageService(await SharedPreferences.getInstance()));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
          value: posts,
          child: const CalendarView(),
        ),
      ),
    ));
    await tester.pump();
    return posts;
  }

  testWidgets('dragging a block to another hour reschedules it, and undo works',
      (tester) async {
    final posts = await pump(tester, const Size(402, 874));
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day + 1, 8, 30);
    posts.addPost(PostModel(
      id: 'drag',
      caption: 'Drag me',
      mediaUrl: 'a.png',
      scheduledTime: at,
    ));

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final block = find.textContaining('Drag me');
    final start = tester.getCenter(block);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveTo(start + const Offset(0, 104));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = posts.posts.firstWhere((p) => p.id == 'drag').scheduledTime;
    expect(moved, at.add(const Duration(hours: 2)));

    posts.undoLastReorder();
    expect(posts.posts.firstWhere((p) => p.id == 'drag').scheduledTime, at);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a published post cannot be dragged', (tester) async {
    final posts = await pump(tester, const Size(402, 874));
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day + 1, 8, 30);
    posts.addPost(PostModel(
      id: 'done',
      caption: 'Already out',
      mediaUrl: 'a.png',
      scheduledTime: at,
      status: 'published',
    ));

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    final start = tester.getCenter(find.textContaining('Already out'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveTo(start + const Offset(0, 104));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(posts.posts.firstWhere((p) => p.id == 'done').scheduledTime, at);
  });

  testWidgets('month and week lay out at phone and desktop widths',
      (tester) async {
    for (final size in const [Size(402, 874), Size(1280, 800)]) {
      await pump(tester, size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
