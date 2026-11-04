import 'dart:convert';
import 'dart:io';

import 'package:lema_daemon/accounts.dart';
import 'package:lema_daemon/daemon.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

class MemorySecrets implements Secrets {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late Directory home;
  late MemorySecrets secrets;
  late List<Map<String, String>> posted;
  late (int, Map<String, dynamic>) Function() answer;
  var now = DateTime(2026, 11, 5, 12);
  const redirect = 'http://127.0.0.1:3001/oauth/callback';

  Accounts make() => Accounts(home, secrets, clock: () => now, post: (url, form) async {
        posted.add(form);
        return answer();
      });

  setUp(() {
    home = Directory.systemTemp.createTempSync('lema_accounts');
    secrets = MemorySecrets();
    posted = [];
    now = DateTime(2026, 11, 5, 12);
    answer = () => (200, {'access_token': 'A1', 'refresh_token': 'R1', 'expires_in': 7200});
    File('${home.path}/providers.json').writeAsStringSync(jsonEncode({
      'x': {'authUrl': 'https://x.test/auth', 'tokenUrl': 'https://x.test/token', 'clientId': 'cid', 'scopes': 'post'},
    }));
  });
  tearDown(() => home.deleteSync(recursive: true));

  Future<void> connect(Accounts a) async {
    final url = Uri.parse(a.start('x', redirect));
    await a.finish({'state': url.queryParameters['state']!, 'code': 'c'});
  }

  test('sign-in uses PKCE and keeps tokens out of files', () async {
    final a = make();
    final url = Uri.parse(a.start('x', redirect));
    final q = url.queryParameters;
    expect(q['code_challenge_method'], 'S256');
    await a.finish({'state': q['state']!, 'code': 'c'});

    final challenge = base64UrlEncode(
            sha256.convert(ascii.encode(posted.single['code_verifier']!)).bytes)
        .replaceAll('=', '');
    expect(q['code_challenge'], challenge);
    expect(await a.accessToken('x'), 'A1');
    expect(a.statuses(), {'x': 'connected'});
    for (final f in home.listSync().whereType<File>()) {
      expect(f.readAsStringSync(), isNot(contains('A1')));
      expect(f.readAsStringSync(), isNot(contains('R1')));
    }
  });

  test('a wrong or reused state connects nothing', () async {
    final a = make();
    final state = Uri.parse(a.start('x', redirect)).queryParameters['state']!;
    expect(await a.finish({'state': 'forged', 'code': 'c'}), contains('old or unknown'));
    expect(posted, isEmpty);
    await a.finish({'state': state, 'code': 'c'});
    expect(await a.finish({'state': state, 'code': 'c'}), contains('old or unknown'));
    expect(posted.length, 1);
  });

  test('a login older than ten minutes is refused', () async {
    final a = make();
    final state = Uri.parse(a.start('x', redirect)).queryParameters['state']!;
    now = now.add(const Duration(minutes: 11));
    expect(await a.finish({'state': state, 'code': 'c'}), contains('old or unknown'));
  });

  test('a platform with no app says so', () {
    expect(() => make().start('tiktok', redirect), throwsA(isA<AccountError>()));
  });

  test('refresh waits until an hour before expiry and keeps the old refresh token', () async {
    final a = make();
    await connect(a);
    posted.clear();
    await a.refreshDue();
    expect(posted, isEmpty);

    now = now.add(const Duration(minutes: 61));
    answer = () => (200, {'access_token': 'A2', 'expires_in': 7200});
    await a.refreshDue();
    expect(posted.single['refresh_token'], 'R1');
    expect(await a.accessToken('x'), 'A2');
    expect(jsonDecode(secrets.values['token:x']!)['refresh'], 'R1');
  });

  test('a refused refresh asks for reconnect; a network failure does not', () async {
    final a = make();
    await connect(a);
    now = now.add(const Duration(minutes: 61));
    answer = () => throw const SocketException('offline');
    await a.refreshDue();
    expect(a.statuses(), {'x': 'connected'});

    answer = () => (400, {'error': 'invalid_grant'});
    await a.refreshDue();
    expect(a.statuses(), {'x': 'expired'});
    expect(make().statuses(), {'x': 'expired'}, reason: 'survives a restart');
  });

  test('disconnect removes the token and status', () async {
    final a = make();
    await connect(a);
    await a.remove('x');
    expect(a.statuses(), isEmpty);
    expect(secrets.values, isEmpty);
  });

  test('routes: token required, callback open, answers never hold tokens', () async {
    final d = Daemon(home, fakeAdapter, clock: () => now, secrets: secrets,
        tokenPost: (url, form) async => answer());
    await d.serve(port: 0);
    addTearDown(() => d.close());
    final client = HttpClient();
    addTearDown(client.close);
    Future<(int, String)> call(String method, String path, {bool auth = true}) async {
      final req = await client.open(method, '127.0.0.1', d.port, path);
      if (auth) req.headers.set('x-lema-token', d.token);
      final res = await req.close();
      return (res.statusCode, await utf8.decodeStream(res));
    }

    expect((await call('GET', '/api/accounts', auth: false)).$1, 401);
    expect((await call('POST', '/api/accounts/tiktok/connect')).$1, 409);
    final started = await call('POST', '/api/accounts/x/connect');
    final url = Uri.parse(jsonDecode(started.$2)['url'] as String);
    expect(url.queryParameters['redirect_uri'], 'http://127.0.0.1:${d.port}/oauth/callback');

    final state = url.queryParameters['state']!;
    final page = await call('GET', '/oauth/callback?state=$state&code=c', auth: false);
    expect(page.$2, contains('Connected'));
    final listed = await call('GET', '/api/accounts');
    expect(jsonDecode(listed.$2), {'x': 'connected'});
    expect(listed.$2 + page.$2, isNot(contains('A1')));

    expect((await call('DELETE', '/api/accounts/x')).$1, 200);
    expect(jsonDecode((await call('GET', '/api/accounts')).$2), isEmpty);
  });

  test('real keychain round trip', () async {
    final k = KeychainSecrets('lema-daemon-test');
    await k.write('t', 'val "quoted" é');
    expect(await k.read('t'), 'val "quoted" é');
    await k.delete('t');
    expect(await k.read('t'), isNull);
  }, skip: !Platform.isMacOS);
}
