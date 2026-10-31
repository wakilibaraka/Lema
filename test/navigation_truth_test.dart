import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/main.dart';
import 'package:lema/core/destinations.dart';
import 'package:lema/core/providers/app_provider.dart';
import 'package:lema/core/services/storage_service.dart';
import 'package:lema/core/shell.dart';

Future<void> _boot(WidgetTester tester,
    {Size size = const Size(1280, 860)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  StorageService(prefs);
  await tester.pumpWidget(const LemaApp());
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('five uniquely named destinations, Analytics first', () {
    final labels = lemaDestinations.map((d) => d.label).toList();
    expect(labels, ['Analytics', 'Queue', 'Composer', 'Vault', 'Settings']);
    expect(destinationIndexOf('Nope'), -1);
  });

  testWidgets('phone shows a bottom bar, the title and quick draft',
      (tester) async {
    await _boot(tester, size: const Size(402, 900));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('quick_draft')), findsOneWidget);

    final app = tester.element(find.byType(LemaShell)).read<AppProvider>();
    app.setNavIndex(settingsDestinationIndex);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('quick draft hides on the composer itself', (tester) async {
    await _boot(tester, size: const Size(402, 900));
    tester
        .element(find.byType(LemaShell))
        .read<AppProvider>()
        .setNavIndex(composerDestinationIndex);
    // The FAB animates out over several frames.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('quick_draft')), findsNothing);
  });

  testWidgets('desktop sidebar collapses and remembers it', (tester) async {
    await _boot(tester);
    expect(find.byType(NavigationBar), findsNothing);
    final app = tester.element(find.byType(LemaShell)).read<AppProvider>();
    expect(app.sidebarCollapsed, isFalse);

    await tester.tap(find.byKey(const ValueKey('sidebar_toggle')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(app.sidebarCollapsed, isTrue);
    expect(StorageService.instance.sidebarCollapsed(), isTrue);
  });
}
