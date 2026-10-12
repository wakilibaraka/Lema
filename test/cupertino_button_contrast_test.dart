import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/main.dart';
import 'package:lema/providers/app_provider.dart';
import 'package:lema/services/storage_service.dart';

/// Guards against the invisible-CupertinoButton regression.
///
/// A plain `CupertinoButton(color: X)` (as opposed to `.filled` / `.tinted`)
/// resolves its foreground to `CupertinoTheme.primaryColor` — which is
/// `#007AFF`, exactly the same value as `AppleTheme.systemBlue`. Any button
/// that passes `systemBlue` as its background and does not set its own
/// foreground renders its label in the same colour as the slab behind it:
/// a blank blue rectangle. That shipped in seven places before this test
/// existed.
///
/// This walks the real element tree of every destination and compares the
/// effective foreground of each Text/Icon against the resolved background of
/// its enclosing enabled button, so it catches new occurrences too.
void main() {
  const viewCount = 11; // Home … Settings, Simulation Engine.

  List<String> scan(WidgetTester tester) {
    final violations = <String>[];
    for (final element in tester.allElements) {
      final widget = element.widget;

      // Resolve the colour actually painted: a widget's own style wins over
      // the ambient DefaultTextStyle / IconTheme, so only fall back when the
      // widget leaves the colour unset. (Reading the ambient value alone
      // produces false positives on buttons that do set an explicit colour.)
      Color? foreground;
      String what;
      if (widget is Text) {
        foreground =
            widget.style?.color ?? DefaultTextStyle.of(element).style.color;
        what = 'Text "${widget.data ?? ''}"';
      } else if (widget is Icon) {
        foreground = widget.color ?? IconTheme.of(element).color;
        what = 'Icon ${widget.icon}';
      } else {
        continue;
      }
      if (foreground == null) continue;

      CupertinoButton? button;
      element.visitAncestorElements((ancestor) {
        final w = ancestor.widget;
        if (w is CupertinoButton) {
          button = w;
          return false;
        }
        return true;
      });

      final b = button;
      if (b == null || b.color == null || b.onPressed == null) continue;

      final bg = CupertinoDynamicColor.resolve(b.color!, element);
      final fg = CupertinoDynamicColor.resolve(foreground, element);
      if (fg.toARGB32() == bg.toARGB32()) {
        violations.add(
          '$what paints 0x${fg.toARGB32().toRadixString(16).padLeft(8, '0')} '
          'on the same colour — invisible on its button',
        );
      }
    }
    return violations;
  }

  testWidgets(
      'no CupertinoButton paints its foreground in its own background colour',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'lema_intro_showcase_seen': true,
    });
    await StorageService.init();

    await tester.pumpWidget(const LemaApp());
    await tester.pumpAndSettle();

    final app =
        tester.element(find.byType(MainLayoutScreen)).read<AppProvider>();

    final violations = <String, List<String>>{};
    for (var index = 0; index < viewCount; index++) {
      app.setNavIndex(index);
      await tester.pumpAndSettle();
      final found = scan(tester);
      if (found.isNotEmpty) violations['nav $index'] = found;
    }

    expect(
      violations,
      isEmpty,
      reason: 'Buttons rendering invisible content:\n'
          '${violations.entries.map((e) => '  ${e.key}:\n      ${e.value.join('\n      ')}').join('\n')}',
    );
  });
}
