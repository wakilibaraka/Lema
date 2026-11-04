import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lema/core/models/media_asset.dart';
import 'package:lema/core/providers/app_provider.dart';
import 'package:lema/core/providers/auth_provider.dart';
import 'package:lema/core/providers/media_provider.dart';
import 'package:lema/core/providers/posts_provider.dart';
import 'package:lema/core/providers/profile_provider.dart';
import 'package:lema/core/services/storage_service.dart';
import 'package:lema/core/shell.dart';

MediaAsset asset(String id, List<String> tags, {String? name}) => MediaAsset(
      id: id,
      url: 'assets/samples/$id.png',
      name: name ?? id,
      kind: kindImage,
      tags: tags,
      addedAt: DateTime(2026),
    );

void main() {
  test('filters by tag and by name or tag text', () {
    final all = [asset('a', ['reel']), asset('b', ['promo'], name: 'Launch')];
    expect(filterAssets(all, tag: 'reel').single.id, 'a');
    expect(filterAssets(all, query: 'LAUN').single.id, 'b');
    expect(filterAssets(all, query: 'pro').single.id, 'b');
    expect(filterAssets(all, tag: 'reel', query: 'laun'), isEmpty);
  });

  test('typed tags are cleaned and deduplicated', () {
    expect(parseTags('Reel, #promo, reel, '), ['reel', 'promo']);
  });

  test('assets and tag edits survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService(await SharedPreferences.getInstance());
    final media = MediaProvider(storage);
    media.add(asset('new', ['one']));
    media.setTags('new', ['two']);

    final reloaded = MediaProvider(storage).assets.firstWhere((a) => a.id == 'new');
    expect(reloaded.tags, ['two']);
    expect(reloaded.addedAt, DateTime(2026));
  });

  testWidgets('Use in post attaches the asset and keeps the written text', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final app = AppProvider();
    await tester.pumpWidget(MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider(create: (_) => PostsProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => MediaProvider()),
        ],
        child: const LemaShell(),
      ),
    ));
    await tester.pump();

    app.setNavIndex(2);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Kept');
    app.setNavIndex(3);
    await tester.pump();
    app.useInPost(asset('pick', const [], name: 'Picked file'));
    await tester.pump();

    expect(find.text('Picked file'), findsOneWidget);
    expect(find.text('Kept'), findsOneWidget);
  });
}
