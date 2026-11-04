import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Where token values live. They never go in a file or an API answer.
abstract class Secrets {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The macOS login keychain, through Apple's `security` tool.
// shortcut: macOS only, add Linux and Windows stores when the daemon ships there.
class KeychainSecrets implements Secrets {
  final String service;
  KeychainSecrets([this.service = 'lema-daemon']);

  @override
  Future<String?> read(String key) async {
    final r = await Process.run(
        'security', ['find-generic-password', '-s', service, '-a', key, '-w']);
    if (r.exitCode != 0) return null;
    return utf8.decode(base64Decode('${r.stdout}'.trim()));
  }

  // Sent over stdin, because arguments are visible to every process in `ps`.
  @override
  Future<void> write(String key, String value) async {
    final encoded = base64Encode(utf8.encode(value));
    final p = await Process.start('security', ['-i']);
    final out = p.stdout.drain<void>();
    final err = p.stderr.transform(utf8.decoder).join();
    p.stdin.writeln(
        'add-generic-password -U -s "$service" -a "$key" -w "$encoded"');
    await p.stdin.close();
    await out;
    final problem = await err;
    if (await p.exitCode != 0 || problem.trim().isNotEmpty) {
      throw StateError('Could not save to the keychain');
    }
  }

  @override
  Future<void> delete(String key) async {
    await Process.run(
        'security', ['delete-generic-password', '-s', service, '-a', key]);
  }
}

class AccountError implements Exception {
  final int status;
  final String message;
  AccountError(this.status, this.message);
}

/// Answers a form POST to a platform's token URL with (status, JSON body).
typedef TokenPost = Future<(int, Map<String, dynamic>)> Function(
    Uri url, Map<String, String> form);

Future<(int, Map<String, dynamic>)> httpTokenPost(
    Uri url, Map<String, String> form) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
    req.headers.set('accept', 'application/json');
    req.write(Uri(queryParameters: form).query);
    final res = await req.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decodeStream(res);
    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      json = {};
    }
    return (res.statusCode, json);
  } finally {
    client.close(force: true);
  }
}

/// Public details of the apps Lema knows how to connect. LinkedIn's standard
/// flow is a client secret with no PKCE and no refresh tokens: 60 days, then
/// the user signs in again.
const knownProviders = <String, Map<String, dynamic>>{
  'linkedin': {
    'authUrl': 'https://www.linkedin.com/oauth/v2/authorization',
    'tokenUrl': 'https://www.linkedin.com/oauth/v2/accessToken',
    'scopes': 'openid profile w_member_social',
    'pkce': false,
  },
};

const _refreshBefore = Duration(hours: 1);
const _loginWindow = Duration(minutes: 10);

class _Login {
  final String platform, verifier, redirect;
  final DateTime at;
  _Login(this.platform, this.verifier, this.redirect, this.at);
}

/// Platform connections: OAuth with PKCE, keychain tokens, refresh before expiry.
///
/// `providers.json` holds each platform's public app details:
/// `{"linkedin": {"authUrl", "tokenUrl", "clientId", "scopes"}}`. A client
/// secret, if the platform needs one, goes in the keychain through
/// `bin/set_client_secret.dart`.
class Accounts {
  final Directory home;
  final Secrets secrets;
  final TokenPost post;
  final DateTime Function() clock;
  final Map<String, _Login> _logins = {};
  final Map<String, Map<String, dynamic>> _accounts = {};

  Accounts(this.home, this.secrets,
      {TokenPost? post, DateTime Function()? clock})
      : post = post ?? httpTokenPost,
        clock = clock ?? DateTime.now {
    if (_file.existsSync()) {
      final saved = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      saved.forEach((k, v) => _accounts[k] = Map<String, dynamic>.from(v as Map));
    }
  }

  File get _file => File('${home.path}/accounts.json');

  void _save() {
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(_accounts), flush: true);
    tmp.renameSync(_file.path);
  }

  Map<String, dynamic>? _provider(String platform) {
    final file = File('${home.path}/providers.json');
    if (!file.existsSync()) return null;
    return (jsonDecode(file.readAsStringSync()) as Map)[platform]
        as Map<String, dynamic>?;
  }

  static String _random() {
    final rng = Random.secure();
    return base64UrlEncode(List.generate(32, (_) => rng.nextInt(256)))
        .replaceAll('=', '');
  }

  /// Status only, safe to hand to the app.
  Map<String, String> statuses() => {
        for (final e in _accounts.entries) e.key: _status(e.value),
      };

  String _status(Map<String, dynamic> a) {
    if (a['needsReconnect'] == true) return 'expired';
    final at = DateTime.tryParse('${a['expiresAt']}');
    if (at == null) return 'connected';
    final left = at.difference(clock());
    if (left <= Duration.zero) return 'expired';
    // A short-lived token that refreshes itself is nothing to warn about.
    if (a['canRefresh'] == true) return 'connected';
    return left <= const Duration(days: 7) ? 'expiringSoon' : 'connected';
  }

  /// The URL to open in the system browser.
  String start(String platform, String redirect) {
    final p = _provider(platform);
    if (p == null) {
      throw AccountError(409, 'Lema has no developer app for $platform yet');
    }
    _logins.removeWhere((_, l) => clock().difference(l.at) > _loginWindow);
    redirect = '${p['redirect'] ?? redirect}';
    final pkce = p['pkce'] != false;
    final state = _random();
    final verifier = _random();
    _logins[state] = _Login(platform, verifier, redirect, clock());
    final challenge = base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final base = Uri.parse('${p['authUrl']}');
    return base.replace(queryParameters: {
      ...base.queryParameters,
      'response_type': 'code',
      'client_id': '${p['clientId']}',
      'redirect_uri': redirect,
      'scope': '${p['scopes'] ?? ''}',
      'state': state,
      if (pkce) 'code_challenge': challenge,
      if (pkce) 'code_challenge_method': 'S256',
    }).toString();
  }

  /// Finishes a login from the browser's redirect. Returns the page's message.
  Future<String> finish(Map<String, String> query) async {
    final login = _logins.remove(query['state']);
    if (login == null || clock().difference(login.at) > _loginWindow) {
      return 'This sign-in link is old or unknown. Start again from Lema.';
    }
    final code = query['code'];
    if (code == null) return 'The platform did not connect (${query['error'] ?? 'no code'}).';
    final p = _provider(login.platform);
    if (p == null) return 'Lema has no developer app for ${login.platform}.';
    final form = {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': login.redirect,
      'client_id': '${p['clientId']}',
      if (p['pkce'] != false) 'code_verifier': login.verifier,
    };
    final secret = await secrets.read('client-secret:${login.platform}');
    if (secret != null) form['client_secret'] = secret;
    try {
      final (status, json) = await post(Uri.parse('${p['tokenUrl']}'), form);
      if (status != 200 || json['access_token'] == null) {
        return 'The platform refused the sign-in (HTTP $status). Start again from Lema.';
      }
      await _store(login.platform, json, null);
      return 'Connected. You can close this tab and go back to Lema.';
    } catch (_) {
      return 'Could not reach the platform. Start again from Lema.';
    }
  }

  Future<void> _store(String platform, Map<String, dynamic> json, String? oldRefresh) async {
    final refresh = json['refresh_token'] ?? oldRefresh;
    await secrets.write(
        'token:$platform',
        jsonEncode({'access': json['access_token'], 'refresh': refresh}));
    final seconds = json['expires_in'];
    _accounts[platform] = {
      'canRefresh': refresh != null,
      'expiresAt': seconds is num
          ? clock().add(Duration(seconds: seconds.toInt())).toIso8601String()
          : null,
    };
    _save();
  }

  Future<String?> accessToken(String platform) async {
    final raw = await secrets.read('token:$platform');
    return raw == null ? null : (jsonDecode(raw) as Map)['access'] as String?;
  }

  Future<void> remove(String platform) async {
    await secrets.delete('token:$platform');
    _accounts.remove(platform);
    _save();
  }

  /// Refreshes anything close to expiry. Only a platform's refusal asks the
  /// user to reconnect; a network failure tries again next time.
  Future<void> refreshDue() async {
    for (final platform in _accounts.keys.toList()) {
      final a = _accounts[platform]!;
      final at = DateTime.tryParse('${a['expiresAt']}');
      if (a['needsReconnect'] == true || at == null) continue;
      if (at.difference(clock()) > _refreshBefore) continue;
      final raw = await secrets.read('token:$platform');
      final refresh = raw == null ? null : (jsonDecode(raw) as Map)['refresh'] as String?;
      final p = _provider(platform);
      if (refresh == null || p == null) {
        if (raw == null || !at.isAfter(clock())) _reconnect(a);
        continue;
      }
      final form = {
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
        'client_id': '${p['clientId']}',
      };
      final secret = await secrets.read('client-secret:$platform');
      if (secret != null) form['client_secret'] = secret;
      try {
        final (status, json) = await post(Uri.parse('${p['tokenUrl']}'), form);
        if (status == 200 && json['access_token'] != null) {
          await _store(platform, json, refresh);
        } else if (status == 400 || status == 401) {
          _reconnect(a);
        }
      } on SocketException {
        // Offline. Next pass.
      } on HttpException {
        // Same.
      } on TimeoutException {
        // Same.
      }
    }
  }

  /// The platform rejected the token.
  void markExpired(String platform) {
    final a = _accounts[platform];
    if (a != null) _reconnect(a);
  }

  void _reconnect(Map<String, dynamic> a) {
    a['needsReconnect'] = true;
    _save();
  }
}
