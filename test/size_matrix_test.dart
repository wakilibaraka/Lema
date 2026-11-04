import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/core/providers/app_provider.dart';
import 'package:lema/core/providers/auth_provider.dart';
import 'package:lema/core/providers/posts_provider.dart';
import 'package:lema/core/providers/profile_provider.dart';
import 'package:lema/core/services/storage_service.dart';
import 'package:lema/features/analytics/analytics_view.dart';
import 'package:lema/theme/backdrop_theme.dart';
import 'package:lema/features/queue_calendar/calendar_view.dart';
import 'package:lema/views/queue_view.dart';
import 'package:lema/views/settings_view.dart';

/// Slice 23: ratios audit matrix.
///
/// Every primary view is pumped at phone (402pt, 430pt) and tablet (768pt)
/// widths, at 1.0x and 1.2x text scale, in light and dark — asserting zero
/// render overflows. This is the executable form of the "different screen
/// ratios" audit: any view that can't survive the matrix blocks the suite.
///
/// NOTE: widget tests must not use real `Future.delayed` (fake-async
/// deadlock); providers are constructed directly with fresh mock prefs.
void main() {
  // Logical sizes under test.
  const sizes = <String, Size>{
    '402pt phone': Size(402, 874),
    '430pt max': Size(430, 932),
    '768pt tablet': Size(768, 1024),
  };

  Widget host(Widget view,
      {double textScale = 1.0, bool dark = false}) {
    return MaterialApp(
      theme: BackdropTheme.lightTheme,
      darkTheme: BackdropTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Builder(
        builder: (context) {
          final data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => AppProvider()),
                ChangeNotifierProvider(create: (_) => PostsProvider()),
                ChangeNotifierProvider(create: (_) => ProfileProvider()),
                // SettingsView watches AuthProvider for the connected-
                // accounts card; omitting it threw ProviderNotFound.
                ChangeNotifierProvider(create: (_) => AuthProvider()),
              ],
              child: view,
            ),
          );
        },
      ),
    );
  }

  Future<void> pumpMatrix(
    WidgetTester tester,
    Widget view,
    String name,
  ) async {
    addTearDown(tester.view.reset);
    for (final entry in sizes.entries) {
      tester.view.physicalSize =
          Size(entry.value.width * 3, entry.value.height * 3);
      tester.view.devicePixelRatio = 3;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      StorageService(prefs);
      await tester.pumpWidget(host(view));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull,
          reason: '$name light @ ${entry.key}');
    }

    // Stress case: dark + max text scale on the smallest phone.
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    StorageService(prefs);
    await tester.pumpWidget(host(view, textScale: 1.2, dark: true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull, reason: '$name dark 1.2x @ 402pt');
  }

  tearDown(() {});

  group('Size matrix (Slice 23)', () {
    testWidgets('Analytics survives all ratios', (tester) async {
      await pumpMatrix(tester, const AnalyticsView(), 'Analytics');
    });

    testWidgets('Queue survives all ratios', (tester) async {
      await pumpMatrix(tester, const QueueView(), 'Queue');
    });



    testWidgets('Settings survives all ratios', (tester) async {
      await pumpMatrix(tester, const SettingsView(), 'Settings');
    });

    testWidgets('Calendar survives all ratios', (tester) async {
      await pumpMatrix(tester, const CalendarView(), 'Calendar');
    });
  });
}
