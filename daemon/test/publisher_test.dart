import 'dart:convert';
import 'dart:io';

import 'package:lema_daemon/accounts.dart';
import 'package:lema_daemon/daemon.dart';
import 'package:lema_daemon/publisher.dart';
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
  late Accounts accounts;
  late Publisher pub;
  late List<(String, Uri, Map<String, String>, List<int>?)> calls;
  late Answer Function(String method, Uri url) reply;
  final post = {'id': 'composer_1793000000000_linkedin', 'platforms': ['linkedin'], 'caption': 'Hello (world) #launch', 'mediaUrl': ''};

  Answer ok(int status, [String body = '{}', Map<String, String> headers = const {}]) =>
      (status: status, headers: headers, body: body);

  Future<void> connect() async {
    File('${home.path}/providers.json').writeAsStringSync(jsonEncode({
      'linkedin': {...knownProviders['linkedin']!, 'clientId': 'cid'}
    }));
    final url = Uri.parse(accounts.start('linkedin', 'http://127.0.0.1:3001/oauth/callback'));
    await accounts.finish({'state': url.queryParameters['state']!, 'code': 'c'});
  }

  setUp(() async {
    home = Directory.systemTemp.createTempSync('lema_pub');
    accounts = Accounts(home, MemorySecrets(),
        post: (u, f) async => (200, {'access_token': 'TOK', 'expires_in': 5184000}));
    calls = [];
    reply = (m, u) {
      if (u.path == '/v2/userinfo') return ok(200, '{"sub":"abc"}');
      return ok(201, '', {'x-restli-id': 'urn:li:share:1'});
    };
    pub = Publisher(accounts, Directory('${home.path}/uploads'), send: (m, u, h, b) async {
      calls.add((m, u, h, b));
      return reply(m, u);
    });
  });
  tearDown(() => home.deleteSync(recursive: true));

  test('text post uses the documented request and returns its link', () async {
    await connect();
    final result = await pub(post);
    final made = calls.last;
    expect(made.$2.toString(), 'https://api.linkedin.com/rest/posts');
    expect(made.$3['Linkedin-Version'], linkedInVersion);
    expect(made.$3['X-Restli-Protocol-Version'], '2.0.0');
    expect(made.$3['Authorization'], 'Bearer TOK');
    final body = jsonDecode(utf8.decode(made.$4!));
    expect(body['author'], 'urn:li:person:abc');
    expect(body['commentary'], r'Hello \(world\) #launch');
    expect(result['postUrl'], 'https://www.linkedin.com/feed/update/urn:li:share:1/');
  });

  test('sign-in follows LinkedIn: secretless PKCE fields are left out', () {
    File('${home.path}/providers.json').writeAsStringSync(jsonEncode({
      'linkedin': {...knownProviders['linkedin']!, 'clientId': 'cid'}
    }));
    final q = Uri.parse(accounts.start('linkedin', 'http://x/cb')).queryParameters;
    expect(q.containsKey('code_challenge'), isFalse);
    expect(q['scope'], 'openid profile w_member_social');
  });

  test('image is uploaded first and attached', () async {
    await connect();
    final image = File('${home.path}/a.png')..writeAsBytesSync([1, 2, 3]);
    final base = reply;
    reply = (m, u) => u.path == '/rest/images'
        ? ok(200, '{"value":{"uploadUrl":"https://up.test/1","image":"urn:li:image:9"}}')
        : u.host == 'up.test'
            ? ok(201)
            : base(m, u);
    await pub({...post, 'mediaType': 'image', 'localFilePath': image.path});
    expect(calls.firstWhere((c) => c.$1 == 'PUT').$4, [1, 2, 3]);
    expect(jsonDecode(utf8.decode(calls.last.$4!))['content']['media']['id'], 'urn:li:image:9');
  });

  group('nothing leaves when', () {
    Future<void> refuses(Map<String, dynamic> p, String reason) async {
      await expectLater(pub(p), throwsA(predicate((e) => '$e'.contains(reason))));
      expect(calls, isEmpty);
    }

    test('it is a sample post', () async {
      await connect();
      await refuses({...post, 'id': 'post-3'}, 'sample');
      await refuses({...post, 'id': 'post-3-1793000000000'}, 'sample');
      await refuses({...post, 'id': 'history-4'}, 'sample');
      await refuses({...post, 'id': 'draft-1'}, 'sample');
    });
    test('another channel is unsupported', () async {
      await connect();
      await refuses({...post, 'platforms': ['linkedin', 'x']}, 'cannot publish to x');
    });
    test('the channel is not connected', () => refuses(post, 'not connected'));
    test('the media is missing', () async {
      await connect();
      await refuses({...post, 'localFilePath': '/no/such.png'}, 'media file');
    });
    test('it is a video', () async {
      await connect();
      final f = File('${home.path}/v.mp4')..writeAsBytesSync([1]);
      await refuses({...post, 'mediaType': 'video', 'localFilePath': f.path}, 'Video');
    });
  });

  test('a dropped send or server error is unknown; a refusal is failed', () async {
    await connect();
    final base = reply;
    reply = (m, u) => u.path == '/rest/posts' ? throw const SocketException('x') : base(m, u);
    await expectLater(pub(post), throwsA(isA<ResultUnknown>()));
    reply = (m, u) => u.path == '/rest/posts' ? ok(503) : base(m, u);
    await expectLater(pub(post), throwsA(isA<ResultUnknown>()));
    reply = (m, u) => u.path == '/rest/posts' ? ok(422, '{"message":"too long"}') : base(m, u);
    await expectLater(pub(post), throwsA(predicate((e) => e is! ResultUnknown && '$e'.contains('too long'))));
  });

  test('a 401 marks the channel expired', () async {
    await connect();
    reply = (m, u) => ok(401);
    await expectLater(pub(post), throwsA(anything));
    expect(accounts.statuses()['linkedin'], 'expired');
  });

  test('the daemon stores the link on the post', () async {
    final d = Daemon(home, (p) async => {'postUrl': 'https://l/1'}, secrets: MemorySecrets());
    await d.publishNow('a', {'scheduledTime': '2026-11-05T12:00:00.000'});
    expect(d.posts.single['postUrl'], 'https://l/1');
  });

  test('a token that cannot refresh warns a week ahead', () async {
    await connect();
    expect(accounts.statuses()['linkedin'], 'connected');
    var now = DateTime.now().add(const Duration(days: 54));
    final later = Accounts(home, MemorySecrets(), clock: () => now);
    expect(later.statuses()['linkedin'], 'expiringSoon');
  });
}
