import 'package:flutter_test/flutter_test.dart';
import 'package:lema/main.dart';
import 'package:lema/services/storage_service.dart';
import 'package:lema/widgets/sidebar_navigation.dart';
import 'package:lema/widgets/window_title_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Lema App smoke test', (WidgetTester tester) async {
    // Seed the intro-showcase flag so the first-launch carousel does not
    // cover the layout under test.
    SharedPreferences.setMockInitialValues({
      'lema_intro_showcase_seen': true,
    });
    await StorageService.init();

    await tester.pumpWidget(const LemaApp());
    await tester.pumpAndSettle();

    // 800x600 is >= 768pt, so the shell renders the desktop/tablet layout.
    // The rail hides its labels behind Tooltips, so assert on the chrome and
    // on the Home hero copy instead of a sidebar label.
    expect(find.byType(WindowTitleBar), findsOneWidget);
    expect(find.byType(SidebarNavigation), findsOneWidget);
    // Backdrop header copy (Slice 23) replaced "Where should we post
    // today?" — the smoke test tracks the redesigned prompt.
    expect(find.textContaining("What's your next post?"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
