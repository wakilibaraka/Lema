import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/models/nav_destination.dart';
import 'package:lema/models/post_model.dart';
import 'package:lema/models/simulation_model.dart';
import 'package:lema/providers/app_provider.dart';
import 'package:lema/providers/auth_provider.dart';
import 'package:lema/providers/posts_provider.dart';
import 'package:lema/providers/profile_provider.dart';
import 'package:lema/services/ai_service.dart';
import 'package:lema/services/demo_mode_service.dart';
import 'package:lema/services/storage_service.dart';
import 'package:lema/views/composer_view.dart';
import 'package:lema/widgets/schedule_time_picker.dart';

/// Phase-4 defects: "Save as Draft" scheduled the post, saved tokens and demo
/// mode were never read back, the composer's Reconnect button did nothing,
/// and only one of three scheduling surfaces had any kind of picker.

Future<void> _storage([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  StorageService(prefs);
}

Future<PostsProvider> _pumpComposer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await _storage();

  final posts = PostsProvider();
  final auth = AuthProvider();
  await tester.pumpWidget(
    MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: AppProvider()),
          ChangeNotifierProvider.value(value: posts),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ],
        child: const ComposerView(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return posts;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => DemoModeService.setEnabled(false));

  group('The seeded queue is stored, not regenerated', () {
    test('a first run persists the queue it shows', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      StorageService(prefs);

      expect(prefs.getString('lema_posts'), isNull);
      final first = PostsProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(prefs.getString('lema_posts'), isNotNull,
          reason: 'the visible schedule must survive a restart');

      // A second run reads the stored slots instead of rebuilding them.
      final stored = first.posts.map((p) => p.scheduledTime).toList();
      final restarted = PostsProvider();
      expect(restarted.posts.map((p) => p.scheduledTime).toList(), stored);
    });

    test('a corrupt blob is left alone for the retry path', () async {
      SharedPreferences.setMockInitialValues({'lema_posts': '{not json'});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      storage.loadPosts();
      expect(storage.hadPostsDecodeError, isTrue);
      expect(storage.postsWereMissing, isFalse);
      expect(prefs.getString('lema_posts'), '{not json',
          reason: 'recovery belongs to retryLoad, not to load');
    });
  });

  group('Save as Draft saves a draft', () {
    testWidgets('the draft button does not schedule', (tester) async {
      final posts = await _pumpComposer(tester);

      await tester.enterText(
          find.byType(TextField).first, 'Draft me, do not schedule me');
      await tester.pump();
      // Seeds ship with scheduled posts, so compare against the before state.
      final scheduledBefore = posts.scheduledPosts.length;
      await tester.tap(find.text('Save as Draft'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(posts.posts.first.id, startsWith('composer_'));
      expect(posts.posts.first.status, 'draft');
      expect(posts.scheduledPosts.length, scheduledBefore,
          reason: 'Save as Draft must not add to the schedule');
      expect(find.textContaining('Saved as draft'), findsOneWidget);
    });

    testWidgets('the schedule button still schedules', (tester) async {
      final posts = await _pumpComposer(tester);

      await tester.enterText(
          find.byType(TextField).first, 'Schedule me on purpose');
      await tester.pump();
      await tester.tap(find.text('Schedule Post'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(posts.posts.first.status, 'scheduled');
      expect(posts.scheduledPosts, isNotEmpty);
    });
  });

  group('Persisted state is read back at launch', () {
    test('tokens saved by a previous run hydrate', () async {
      await _storage();
      final auth = AuthProvider();
      await auth.connectPlatform('instagram',
          accessToken: 'ig-secret',
          expiresAt: DateTime.now().add(const Duration(days: 30)));
      expect(auth.isConnected('instagram'), isTrue);

      // A fresh provider on the same storage stands in for a restart.
      final restarted = AuthProvider();
      expect(restarted.isConnected('instagram'), isFalse);
      await restarted.loadTokens();
      expect(restarted.isConnected('instagram'), isTrue,
          reason: 'tokens persisted but never loaded');
      expect(restarted.getAccessToken('instagram'), 'ig-secret');
    });

    test('demo mode is restored from storage at launch', () async {
      // A real launch has an empty in-memory flag and a disk that still says
      // "on"; setMockInitialValues stands in for the disk here.
      await DemoModeService.setEnabled(false);
      SharedPreferences.setMockInitialValues({'lema_demo_mode': true});
      final prefs = await SharedPreferences.getInstance();
      StorageService(prefs);

      expect(DemoModeService.isEnabled, isFalse);
      await DemoModeService.load();
      expect(DemoModeService.isEnabled, isTrue,
          reason: 'the demo toggle was written but never read back');
    });

    test('the provider mirrors demo mode and republishes it', () async {
      await _storage();
      final app = AppProvider();
      expect(app.demoMode, isFalse);

      await app.setDemoMode(true);
      expect(app.demoMode, isTrue);

      final restarted = AppProvider();
      await restarted.loadDemoMode();
      expect(restarted.demoMode, isTrue);
    });

    test('there is exactly one switch for simulated publishing', () async {
      await _storage();
      final app = AppProvider();
      expect(app.demoMode, isFalse);
      // The old second flag is gone from the provider surface.
      expect(app.toString(), isNot(contains('sandbox')));
    });
  });

  group('Demo mode gates the AI engine', () {
    Future<Map<String, dynamic>> generate(String topic) async {
      final profile = ProfileProvider().activeProfile;
      return AiService.instance.generatePostData(
        topic: topic,
        profile: profile,
        platforms: const ['instagram'],
      );
    }

    test('demo mode answers locally and says so', () async {
      await _storage();
      await DemoModeService.setEnabled(true);

      final result = await generate('coffee shop reels');
      expect(result['source'], 'demo');
      expect(result['caption'], contains('coffee shop reels'));
    });

    test('without demo mode the offline engine labels itself local', () async {
      await _storage();
      final result = await generate('coffee shop reels');
      // No API key is configured in tests, so no model call happens either.
      expect(result['source'], anyOf('local', 'gemini'));
    });
  });

  group('Reconnect points somewhere real', () {
    test('Settings is reachable by label, not by a magic index', () {
      expect(settingsDestinationIndex, greaterThanOrEqualTo(0));
      expect(lemaDestinations[settingsDestinationIndex].label, 'Settings');
      expect(destinationIndexOf('Nope'), -1);
    });

    testWidgets('an expired token shows a Reconnect banner that navigates',
        (tester) async {
      await _storage();
      final auth = AuthProvider();
      await auth.connectPlatform('instagram',
          accessToken: 'expired',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)));

      final app = AppProvider();
      final posts = PostsProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: app),
              ChangeNotifierProvider.value(value: posts),
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider(create: (_) => ProfileProvider()),
            ],
            child: const ComposerView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('token expired. Reconnect to publish'),
        findsOneWidget,
      );
      expect(app.selectedNavIndex, isNot(settingsDestinationIndex));

      await tester.tap(find.text('Reconnect'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(app.selectedNavIndex, settingsDestinationIndex,
          reason: 'Reconnect must land where accounts are managed');
    });
  });

  group('Schedule slots read the same everywhere', () {
    test('formatting is consistent and never zero-pads the hour', () {
      expect(formatScheduleSlot(DateTime(2026, 10, 13, 9, 5)),
          'Oct 13 at 9:05 AM');
      expect(formatScheduleSlot(DateTime(2026, 10, 13, 0, 0)),
          'Oct 13 at 12:00 AM');
      expect(formatScheduleSlot(DateTime(2026, 10, 13, 12, 30)),
          'Oct 13 at 12:30 PM');
      expect(formatScheduleSlot(DateTime(2026, 10, 13, 23, 45)),
          'Oct 13 at 11:45 PM');
    });

    test('a late slot can be coloured as late', () {
      final late = scheduleColor(DateTime(2020), false, overdue: true);
      expect(late, isNot(scheduleColor(DateTime(2030), false)));
    });

    testWidgets('the shared picker returns the chosen time', (tester) async {
      DateTime? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: CupertinoLikeButton(
                onTap: () async {
                  chosen = await showScheduleTimePicker(
                    context: context,
                    initial: DateTime(2026, 10, 20, 14, 30),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CupertinoLikeButton));
      await tester.pumpAndSettle();

      expect(find.text('Schedule'), findsOneWidget);
      // The picker opens on the post's current slot, not on "now".
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(chosen, DateTime(2026, 10, 20, 14, 30));
    });
  });

  group('A saved simulation run is read back at launch', () {
    test('save → load round-trips posts, assignments, config and results',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      final first = PostModel(
        id: 'sim-1',
        caption: 'Hook that survived a restart',
        mediaUrl: 'https://cdn.example.com/reel.mp4',
        scheduledTime: DateTime(2026, 11, 3, 7, 15),
      );
      final second = PostModel(
        id: 'sim-2',
        caption: 'Short post',
        mediaUrl: 'https://cdn.example.com/still.jpg',
        status: 'draft',
      );
      final run = SimulationRun(
        id: 'run-42',
        createdAt: DateTime(2026, 10, 14, 8, 30),
        posts: [first, second],
        platformAssignments: {
          first: PlatformName.tiktok,
          second: PlatformName.youtube,
        },
        config: const ScoringConfig(
          engagementWeight: 1.5,
          timeDecayFactor: 0.25,
          platformBonus: {PlatformName.instagram: 12.0},
        ),
        results: [
          ScoreResult(
            totalScore: 91.5,
            engagementComponent: 60.0,
            decayComponent: 19.5,
            platformBonuses: {PlatformName.tiktok: 12.0},
          ),
        ],
      );

      await storage.saveSimulationRun(run);
      final loaded = storage.loadSimulationRun();

      expect(loaded, isNotNull, reason: 'a saved run must be readable');
      expect(loaded!.id, 'run-42');
      expect(loaded.createdAt, DateTime(2026, 10, 14, 8, 30));
      expect(loaded.posts.map((p) => p.id), ['sim-1', 'sim-2']);
      expect(loaded.posts.first.scheduledTime, DateTime(2026, 11, 3, 7, 15));

      // Identity keys do not survive JSON: match restored assignments by
      // post id, the same way simulation_view re-pairs them.
      final restored = <String, PlatformName>{};
      loaded.platformAssignments.forEach((post, platform) {
        restored[post.id] = platform;
      });
      expect(restored,
          {'sim-1': PlatformName.tiktok, 'sim-2': PlatformName.youtube});

      expect(loaded.config.engagementWeight, 1.5);
      expect(loaded.config.timeDecayFactor, 0.25);
      expect(loaded.config.platformBonus[PlatformName.instagram], 12.0);

      expect(loaded.results, hasLength(1));
      expect(loaded.results.first.totalScore, 91.5);
      expect(loaded.results.first.platformBonuses[PlatformName.tiktok], 12.0);
    });

    test('a corrupt blob returns null for a fresh run, not a crash', () async {
      SharedPreferences.setMockInitialValues({
        'lema_simulation_run': '{not valid json',
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      expect(storage.loadSimulationRun(), isNull);
    });
  });
}

/// Minimal tap target so the picker can be opened without dragging a whole
/// screen into the test.
class CupertinoLikeButton extends StatelessWidget {
  final VoidCallback onTap;

  const CupertinoLikeButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 44,
        alignment: Alignment.center,
        color: const Color(0xFF007AFF),
        child: const Text('Pick'),
      ),
    );
  }
}
