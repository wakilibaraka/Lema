import 'package:flutter_test/flutter_test.dart';
import 'package:lema/main.dart';
import 'package:lema/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Lema App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    await tester.pumpWidget(const LemaApp());
    await tester.pumpAndSettle();

    expect(find.text('Device Simulator'), findsWidgets);
  });
}
