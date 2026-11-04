import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/core/models/platform_info.dart';
import 'package:lema/core/models/post_model.dart';
import 'package:lema/core/providers/app_provider.dart';
import 'package:lema/core/providers/auth_provider.dart';
import 'package:lema/core/providers/posts_provider.dart';
import 'package:lema/core/providers/profile_provider.dart';
import 'package:lema/core/services/media_processing_service.dart';
import 'package:lema/core/services/storage_service.dart';
import 'package:lema/features/composer/composer_view.dart';

void main() {
  test('caption rules name the platform and the limit', () {
    expect(captionWarnings('twitter', 'x' * 281, hasMedia: true).single, contains('280'));
    expect(captionWarnings('instagram', 'x' * 281, hasMedia: true), isEmpty);
    final tags = List.generate(31, (i) => '#t$i').join(' ');
    expect(captionWarnings('instagram', tags, hasMedia: true).single, contains('30 hashtags'));
    expect(captionWarnings('youtube', 'x' * 101, hasMedia: true).single, contains('titles'));
    expect(captionWarnings('tiktok', 'hi', hasMedia: false).single, contains('needs'));
  });

  test('a file warns only for the platform that rejects it', () {
    List<MediaValidationIssue> check(String platform) =>
        MediaProcessingService.validateMediaForAllPlatforms(
          filePath: 'a.png',
          platforms: [platform],
          isVideo: false,
        );
    expect(check('instagram'), isEmpty);
    expect(check('tiktok').single.message, contains('TikTok'));
  });

  Future<PostsProvider> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final posts = PostsProvider();
    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AppProvider()),
          ChangeNotifierProvider.value(value: posts),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ],
        child: const ComposerView(),
      ),
    ));
    await tester.pump();
    return posts;
  }

  testWidgets('each selected platform gets a post carrying the repeat', (tester) async {
    final posts = await pump(tester, const Size(1400, 1200));
    await tester.enterText(find.byType(TextField).first, 'Hello');
    await tester.tap(find.widgetWithText(FilterChip, 'LinkedIn'));
    await tester.pump();
    await tester.tap(find.text('Daily'));
    await tester.pump();
    await tester.tap(find.text('Schedule Post'));
    await tester.pump();

    final made = posts.posts.where((p) => p.id.startsWith('composer_')).toList();
    expect(made.map((p) => p.platforms.single).toSet(), {'instagram', 'linkedin'});
    expect(made.every((p) => p.recurrence == recurrenceDaily), isTrue);
  });

  testWidgets('a per-platform override reaches only that platform', (tester) async {
    final posts = await pump(tester, const Size(1400, 1200));
    await tester.enterText(find.byType(TextField).first, 'Main');
    await tester.tap(find.widgetWithText(FilterChip, 'LinkedIn'));
    await tester.pump();
    // Selecting LinkedIn made it the previewed platform.
    await tester.enterText(find.byKey(const ValueKey('override_linkedin')), 'For LinkedIn');
    await tester.pump();
    await tester.tap(find.text('Schedule Post'));
    await tester.pump();

    String captionOn(String p) =>
        posts.posts.firstWhere((x) => x.id.startsWith('composer_') && x.platforms.single == p).caption;
    expect(captionOn('instagram'), 'Main');
    expect(captionOn('linkedin'), 'For LinkedIn');
  });

  testWidgets('no text means nothing to save', (tester) async {
    await pump(tester, const Size(1400, 1200));
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Schedule Post')).onPressed,
      isNull,
    );
  });

  testWidgets('phone layout swaps between edit and preview', (tester) async {
    await pump(tester, const Size(402, 874));
    expect(find.byKey(const ValueKey('override_instagram')), findsNothing);
    await tester.tap(find.text('Preview'));
    await tester.pump();
    expect(find.byKey(const ValueKey('override_instagram')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
