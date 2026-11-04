import 'dart:convert';
import 'dart:io';

import 'package:lema_daemon/daemon.dart';
import 'package:test/test.dart';

void main() {
  late Directory home;
  late List<String> sent;
  var now = DateTime(2026, 11, 4, 12);

  Future<void> record(Map<String, dynamic> p) async => sent.add(p['id'] as String);
  Daemon start([Adapter? adapter]) => Daemon(home, adapter ?? record, clock: () => now);

  Map<String, dynamic> post(String id, DateTime at, {String recurrence = 'none'}) => {
        'id': id,
        'status': 'scheduled',
        'scheduledTime': at.toIso8601String(),
        'recurrence': recurrence,
      };

  setUp(() {
    home = Directory.systemTemp.createTempSync('lema_daemon');
    sent = [];
    now = DateTime(2026, 11, 4, 12);
  });
  tearDown(() => home.deleteSync(recursive: true));

  test('a due post fires once, however many ticks follow', () async {
    final d = start()..sync([post('a', now.subtract(const Duration(minutes: 1)))], {'a'});
    await Future.wait([d.tick(), d.tick()]);
    await d.tick();
    expect(sent, ['a']);
    expect(d.posts.single['status'], 'published');
  });

  test('a future post waits', () async {
    final d = start()..sync([post('a', now.add(const Duration(minutes: 1)))], {'a'});
    await d.tick();
    expect(sent, isEmpty);
  });

  test('a restart does not repeat a published post', () async {
    final d = start()..sync([post('a', now)], {'a'});
    await d.tick();
    await start().tick();
    expect(sent, ['a']);
  });

  test('a crash mid-send is never resent and says why', () async {
    final d = start((_) async {
      // Simulates the process dying: the claim is on disk, the result is not.
      final restarted = Daemon(home, record, clock: () => now);
      await restarted.tick();
      expect(restarted.posts.single['status'], 'failed');
      expect('${restarted.posts.single['failureReason']}', contains('Check the platform'));
    })
      ..sync([post('a', now)], {'a'});
    await d.tick();
    expect(sent, isEmpty);
  });

  test('missed rule: within an hour sends, later is held as failed', () async {
    final d = start()
      ..sync([
        post('late', now.subtract(const Duration(minutes: 59))),
        post('missed', now.subtract(const Duration(minutes: 61))),
      ], {'late', 'missed'});
    await d.tick();
    expect(sent, ['late']);
    final missed = d.posts.firstWhere((p) => p['id'] == 'missed');
    expect(missed['status'], 'failed');
    expect('${missed['failureReason']}', contains('Missed'));
  });

  test('an adapter refusal is stored as the reason and not repeated', () async {
    final d = start((_) async => throw 'Platform said no')..sync([post('a', now)], {'a'});
    await d.tick();
    await d.tick();
    expect(d.posts.single['status'], 'failed');
    expect(d.posts.single['failureReason'], 'Platform said no');
  });

  test('a repeating post queues its next slot, and sync keeps it until seen', () async {
    final d = start()..sync([post('a', now, recurrence: 'daily')], {'a'});
    await d.tick();
    final next = d.posts.firstWhere((p) => p['status'] == 'scheduled');
    expect(next['scheduledTime'], DateTime(2026, 11, 5, 12).toIso8601String());

    // The app hasn't heard of it yet, so its absence is not a delete.
    d.sync([], {'a'});
    expect(d.posts.any((p) => p['id'] == next['id']), isTrue);
    // Once the app has it, removing it is a real delete.
    d.sync([next], {'a', next['id'] as String});
    d.sync([], {'a'});
    expect(d.posts.any((p) => p['id'] == next['id']), isFalse);
  });

  test('sync removes unscheduled posts and forgets deleted history', () async {
    final d = start()..sync([post('a', now), post('b', now.add(const Duration(days: 1)))], {'a', 'b'});
    await d.tick();
    d.sync([], {'a'});
    expect(d.posts.map((p) => p['id']), ['a']);
    d.sync([], {});
    expect(d.posts, isEmpty);
  });

  test('sync cannot revive a sent post; a new time revives a failed one', () async {
    final d = start()..sync([post('a', now)], {'a'});
    await d.tick();
    d.sync([post('a', now.add(const Duration(days: 1)))], {'a'});
    expect(d.posts.single['status'], 'published');

    final f = start((_) async => throw 'no')..sync([post('b', now)], {'a', 'b'});
    await f.tick();
    f.sync([post('b', now)], {'a', 'b'});
    expect(f.posts.firstWhere((p) => p['id'] == 'b')['status'], 'failed');
    f.sync([post('b', now.add(const Duration(days: 1)))], {'a', 'b'});
    expect(f.posts.firstWhere((p) => p['id'] == 'b')['status'], 'scheduled');
  });

  test('publishNow refuses a post already sent', () async {
    final d = start();
    await d.publishNow('a', post('a', now));
    expect(() => d.publishNow('a', post('a', now)), throwsA(isA<PublishRefused>()));
    expect(sent, ['a']);
  });

  test('a corrupt store refuses to start rather than forget what was sent', () {
    File('${home.path}/posts.json').writeAsStringSync('{oops');
    expect(start, throwsFormatException);
  });

  group('http', () {
    late Daemon d;
    late HttpClient client;
    setUp(() async {
      d = start();
      await d.serve(port: 0);
      client = HttpClient();
    });
    tearDown(() async {
      client.close(force: true);
      await d.close();
    });

    Future<(int, String)> call(String method, String path, {String? token, Object? body}) async {
      final req = await client.open(method, '127.0.0.1', d.port, path);
      if (token != null) req.headers.set('x-lema-token', token);
      if (body != null) req.write(jsonEncode(body));
      final res = await req.close();
      return (res.statusCode, await utf8.decodeStream(res));
    }

    test('every api route needs the token', () async {
      expect((await call('GET', '/api/settings')).$1, 401);
      expect((await call('GET', '/api/posts', token: 'wrong')).$1, 401);
      expect((await call('GET', '/api/settings', token: d.token)).$1, 200);
    });

    test('token file is private and survives a restart', () {
      final mode = File('${home.path}/token').statSync().modeString();
      expect(mode, 'rw-------');
      expect(start().token, d.token);
    });

    test('sync, publish, analytics and upload answer', () async {
      final sync = await call('POST', '/api/posts/sync', token: d.token, body: {
        'posts': [post('a', now.add(const Duration(days: 1)))],
        'ids': ['a'],
      });
      expect(sync.$1, 200);
      expect((await call('POST', '/api/posts/b/publish', token: d.token, body: post('b', now))).$1, 200);
      expect((await call('GET', '/api/analytics/b', token: d.token)).$1, 404);

      final up = await call('POST', '/api/upload', token: d.token, body: {
        'name': '../../evil.png',
        'data': 'data:image/png;base64,${base64Encode([1, 2, 3])}',
      });
      final path = jsonDecode(up.$2)['fileUrl'] as String;
      expect(path, matches(RegExp(r'^/uploads/[0-9a-f]{16}\.png$')));
      expect((await call('GET', path)).$1, 200);
      expect((await call('GET', '/uploads/token')).$1, 404);
    });

    test('malformed sync is a 400, not a crash', () async {
      expect((await call('POST', '/api/posts/sync', token: d.token, body: {'posts': 1})).$1, 400);
      expect((await call('GET', '/api/settings', token: d.token)).$1, 200);
    });
  });
}
