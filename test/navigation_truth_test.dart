import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/main.dart';
import 'package:lema/models/nav_destination.dart';
import 'package:lema/providers/app_provider.dart';
import 'package:lema/providers/posts_provider.dart';
import 'package:lema/services/storage_service.dart';
import 'package:lema/widgets/floating_tab_bar.dart';
import 'package:lema/widgets/media_player_widget.dart';

/// Navigation chrome had one screen under three names, and highlighted Home
/// while other screens were on display. Small previews also rendered the
/// full-size playback overlay on top of their artwork. These pin the
/// single-name rule, the honest dock selection, the dock's clearance and the
/// thumbnail treatment.

Future<void> _boot(WidgetTester tester,
    {Size size = const Size(1280, 860)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'lema_intro_showcase_seen': true,
  });
  final prefs = await SharedPreferences.getInstance();
  StorageService(prefs);
  await tester.pumpWidget(const LemaApp());
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('One name per destination', () {
    test('labels are unique and the dock takes the leading five', () {
      final labels = lemaDestinations.map((d) => d.label).toList();
      expect(labels.toSet().length, labels.length);
      expect(lemaDockDestinations.length, lemaDockTabCount);
      expect(lemaDockDestinations.first.label, 'Home');
    });

    test('short labels never outgrow the full label', () {
      for (final d in lemaDestinations) {
        expect(d.shortLabel.length, lessThanOrEqualTo(d.label.length),
            reason: '${d.label} truncates in the mobile app bar otherwise');
      }
    });

    test('the drifting aliases are gone', () {
      final all =
          lemaDestinations.expand((d) => [d.label, d.shortLabel]).toSet();
      for (final stale in [
        'Publish Queue',
        'Publishing Queue',
        'Device Simulator',
        'Content Calendar',
        'AI Studio & Planner',
        'Omnichannel Composer',
        'Hooks & Scripts',
        'Hooks & Scripts Pipeline',
        'Daily Operations Tick',
        'Daemon & Settings',
        'Daemon & System Settings',
        'Simulation Engine',
      ]) {
        expect(all.contains(stale), isFalse, reason: '$stale is a stale name');
      }
    });
  });

  /// AppProvider reads persisted settings, so storage must exist first.
  Future<AppProvider> freshApp() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    StorageService(prefs);
    return AppProvider();
  }

  group('Dock selection tells the truth', () {
    test('a docked destination maps to its own tab', () async {
      final app = await freshApp();
      app.setNavIndex(2);
      expect(app.selectedTabIndex, 2);
    });

    test('a screen outside the dock selects no tab', () async {
      final app = await freshApp();
      app.setNavIndex(9); // Settings
      expect(app.selectedTabIndex, -1);
      app.setNavIndex(lemaDestinations.length - 1);
      expect(app.selectedTabIndex, -1);
    });

    testWidgets('Settings highlights no dock tab', (tester) async {
      await _boot(tester, size: const Size(402, 900));
      final context = tester.element(find.byType(MainLayoutScreen));
      context.read<AppProvider>().setNavIndex(9);
      await tester.pump(const Duration(milliseconds: 400));

      final bar = tester.widget<FloatingTabBar>(find.byType(FloatingTabBar));
      expect(bar.currentIndex, -1);
      // The app bar still says where you are.
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('Home highlights the Home tab', (tester) async {
      await _boot(tester, size: const Size(402, 900));
      final bar = tester.widget<FloatingTabBar>(find.byType(FloatingTabBar));
      expect(bar.currentIndex, 0);
    });
  });

  group('Mobile shell clearance', () {
    testWidgets('the body reserves the docked bar its full height',
        (tester) async {
      await _boot(tester, size: const Size(402, 900));

      final context = tester.element(find.byType(MainLayoutScreen));
      final expected = FloatingTabBar.clearance(context);
      expect(expected, greaterThan(0));

      final padding = tester.widget<Padding>(
          find.byKey(const ValueKey('mobile_body_clearance')));
      final insets = padding.padding as EdgeInsets;
      expect(insets.bottom, expected);
      expect(insets.top, 0);
    });

    testWidgets('the desktop shell has no dock and no clearance',
        (tester) async {
      await _boot(tester);
      expect(find.byType(FloatingTabBar), findsNothing);
      expect(find.byKey(const ValueKey('mobile_body_clearance')), findsNothing);
    });
  });

  group('Sidebar carries real counts', () {
    testWidgets('the queue badge is the scheduled count', (tester) async {
      await _boot(tester);
      final posts =
          tester.element(find.byType(MainLayoutScreen)).read<PostsProvider>();
      expect(posts.scheduledPosts.length, greaterThan(0));

      expect(find.text('Queue'), findsWidgets);
      expect(find.text('${posts.scheduledPosts.length}'), findsWidgets);
    });

    testWidgets('decorative badges are gone and the daemon state is honest',
        (tester) async {
      await _boot(tester);
      for (final filler in ['Buffer', 'Gemini', 'Live', '60s', 'New']) {
        expect(find.text(filler), findsNothing, reason: '$filler was filler');
      }
      // No daemon is running in tests and demo mode is off, so the sidebar
      // must not claim a sandbox is simulating anything.
      expect(find.textContaining('Daemon offline'), findsWidgets);
      expect(find.textContaining('Sandbox'), findsNothing);
    });
  });

  group('Thumbnail treatment', () {
    testWidgets('grid tiles ask for thumbnails; the hero does not',
        (tester) async {
      await _boot(tester, size: const Size(1280, 1600));

      final players =
          tester.widgetList<UniversalMediaPlayer>(find.byType(UniversalMediaPlayer));
      expect(players, isNotEmpty);

      // Grid tiles, calendar/modal previews: thumbnail treatment.
      expect(players.where((p) => p.thumbnail).length, greaterThanOrEqualTo(3));
      // The hero keeps the full theatre treatment.
      expect(players.where((p) => p.autoPlay && !p.thumbnail).length, 1);
    });

    testWidgets('a thumbnail never renders the decode-error card',
        (tester) async {
      Future<void> pumpThumb({required bool thumbnail}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => AppProvider(),
              child: Center(
                child: SizedBox(
                  width: 80,
                  height: 100,
                  child: UniversalMediaPlayer(
                    mediaUrl: 'assets/samples/emms_story_features.mp4',
                    isVideo: true,
                    autoPlay: false,
                    showControls: false,
                    thumbnail: thumbnail,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      SharedPreferences.setMockInitialValues({});
      await pumpThumb(thumbnail: true);
      expect(find.text('Video Preview Standby'), findsNothing);
      expect(find.text('Retry Decode'), findsNothing);

      // The full-size player still offers recovery, which is the point of
      // the two treatments.
      await pumpThumb(thumbnail: false);
      expect(find.text('Video Preview Standby'), findsOneWidget);
      expect(find.text('Retry Decode'), findsOneWidget);
    });
  });
}
