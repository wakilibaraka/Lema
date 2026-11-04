import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import 'daemon_token.dart';
import 'demo_mode_service.dart';

/// What actually happened when a post was handed to the daemon.
enum DispatchOutcome {
  /// The platform has it, or demo mode simulated it (and [DispatchResult.detail] says so).
  published,

  /// Nothing went out. Safe to retry.
  failed,

  /// It may have gone out. Never retried without the user checking first,
  /// so nothing posts twice.
  unknown,
}

class DispatchResult {
  final DispatchOutcome outcome;

  /// Human-readable cause, safe to show next to a Retry action.
  final String? detail;

  const DispatchResult(this.outcome, [this.detail]);

  bool get isPublished => outcome == DispatchOutcome.published;

  @override
  String toString() => detail ?? outcome.name;
}

class ApiService {
  final String baseUrl;

  /// Injectable transport. Production uses a shared real client; tests pass
  /// a stub (package:http MockClient) so retry counts can be asserted
  /// without a live daemon. Nullable to keep this constructor `const`.
  final http.Client? client;

  static ApiService? _instance;
  static final http.Client _sharedClient = http.Client();

  const ApiService({
    this.baseUrl = 'http://localhost:3001',
    this.client,
  });

  http.Client get _http => client ?? _sharedClient;

  static ApiService get instance => _instance ??= const ApiService();

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);

  /// Transport-level retries are deliberately short and few. A refused
  /// connection to a local daemon will not recover inside the backoff
  /// ladder, and the dispatch UI offers an explicit Retry.
  static const int _maxTransportRetries = 1;
  static const Duration _transportRetryDelay = Duration(milliseconds: 250);

  /// 429/5xx get exponential backoff + jitter (rate-limit resilience);
  /// transport failures get one quick retry before propagating as offline.
  Future<http.Response> _withRetry(Future<http.Response> Function() request) =>
      _withStatusRetry(() => _withTransportRetry(request));

  Future<http.Response> _withTransportRetry(
      Future<http.Response> Function() request) async {
    for (int attempt = 0; ; attempt++) {
      try {
        return await request();
      } catch (_) {
        if (attempt >= _maxTransportRetries) rethrow;
        await Future.delayed(_transportRetryDelay);
      }
    }
  }

  Future<http.Response> _withStatusRetry(
      Future<http.Response> Function() request) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      final response = await request();
      if ((response.statusCode == 429 || response.statusCode >= 500) &&
          attempt < _maxRetries) {
        final jitter = Random().nextInt(1000);
        await Future.delayed(
            _baseDelay * (1 << attempt) + Duration(milliseconds: jitter));
        continue;
      }
      return response;
    }
    throw Exception('Max retries exceeded');
  }

  /// Sends the daemon the app's queue and returns its posts, or null when
  /// there is no daemon to talk to. Demo mode never touches the daemon.
  Future<List<Map<String, dynamic>>?> syncPosts(List<PostModel> posts) async {
    if (DemoModeService.isEnabled) return null;
    try {
      final res = await _http
          .post(
            Uri.parse('$baseUrl/api/posts/sync'),
            headers: daemonHeaders(),
            body: jsonEncode({
              'posts': [
                for (final p in posts)
                  if (p.status == 'scheduled') p.toJson(),
              ],
              'ids': [for (final p in posts) p.id],
            }),
          )
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body) as List);
      }
    } catch (_) {
      // No daemon: the app keeps working from its own storage.
    }
    return null;
  }

  /// Connection status per platform, or null with no daemon. Token values
  /// stay in the daemon's keychain and never reach the app.
  Future<Map<String, String>?> fetchAccounts() async {
    try {
      final res = await _http
          .get(Uri.parse('$baseUrl/api/accounts'), headers: daemonHeaders())
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return Map<String, String>.from(jsonDecode(res.body) as Map);
      }
    } catch (_) {
      // No daemon.
    }
    return null;
  }

  /// The sign-in page to open in the browser, or the reason there isn't one.
  Future<({String? url, String? error})> startConnect(String platform) async {
    try {
      final res = await _http
          .post(Uri.parse('$baseUrl/api/accounts/$platform/connect'),
              headers: daemonHeaders())
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return (url: (jsonDecode(res.body) as Map)['url'] as String?, error: null);
      }
      return (url: null, error: _errorIn(res.body) ?? 'HTTP ${res.statusCode}');
    } catch (_) {
      return (url: null, error: 'The daemon is not running');
    }
  }

  Future<bool> disconnectAccount(String platform) async {
    try {
      final res = await _http
          .delete(Uri.parse('$baseUrl/api/accounts/$platform'),
              headers: daemonHeaders())
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkDaemonStatus() async {
    try {
      final res = await _withRetry(() => _http.get(Uri.parse('$baseUrl/api/settings'), headers: daemonHeaders()).timeout(
            const Duration(seconds: 3),
          ));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Hands [post] to the local daemon and reports the real outcome.
  /// The publish POST deliberately bypasses [_withRetry]: a timed-out or
  /// 5xx'd publish may already have gone out, so retrying it would post the
  /// same content twice (review finding 2). The dispatch UI owns Retry.
  /// [_withRetry] stays on the GETs, where a repeat is harmless.
  /// [confirmedNotPosted] is the user saying they checked the platform after
  /// an unknown result; the daemon refuses to resend one without it.
  Future<DispatchResult> dispatchPost(PostModel post,
      {bool confirmedNotPosted = false}) async {
    // Demo mode answers locally: no daemon and no platform APIs are touched,
    // which is what the app-review walkthroughs need.
    // The result is labelled so the UI never claims a real send.
    if (DemoModeService.isEnabled) {
      return const DispatchResult(
          DispatchOutcome.published, 'Demo mode: local publish simulated');
    }

    const mayHaveSent = 'Check the platform before sending again.';
    try {
      final res = await _http
          .post(Uri.parse('$baseUrl/api/posts/${post.id}/publish'),
              headers: daemonHeaders(),
              body: jsonEncode({
                ...post.toJson(),
                if (confirmedNotPosted) 'confirmedNotPosted': true,
              }))
          .timeout(const Duration(seconds: 6));

      final code = res.statusCode;
      if (code >= 200 && code < 300) {
        return const DispatchResult(DispatchOutcome.published);
      }
      final reason = _errorIn(res.body) ?? 'Daemon answered HTTP $code';
      // 502 is the platform refusing; 409 and other 5xx may follow a real send.
      if (code == 502 || (code < 500 && code != 409)) {
        return DispatchResult(DispatchOutcome.failed, reason);
      }
      return DispatchResult(DispatchOutcome.unknown, '$reason. $mayHaveSent');
    } on TimeoutException {
      return const DispatchResult(DispatchOutcome.unknown,
          'No answer from the daemon after 6s. $mayHaveSent');
    } catch (e) {
      // Refused means the request never arrived. Any other break may have
      // come after the daemon started sending.
      if ('$e'.contains('Connection refused')) {
        return const DispatchResult(
            DispatchOutcome.failed, 'The daemon is not running');
      }
      return DispatchResult(
          DispatchOutcome.unknown, 'Connection lost ($e). $mayHaveSent');
    }
  }

  static String? _errorIn(String body) {
    try {
      return (jsonDecode(body) as Map)['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> uploadMedia({
    required String name,
    required String base64Data,
    required String mimeType,
  }) async {
    try {
      final res = await _withRetry(() => _http.post(
        Uri.parse('$baseUrl/api/upload'),
        headers: {'Content-Type': 'application/json', ...daemonHeaders()},
        body: jsonEncode({
          'name': name,
          'type': mimeType,
          'data': 'data:$mimeType;base64,$base64Data',
        }),
      ).timeout(const Duration(seconds: 10)));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['url'] as String?;
      }
    } catch (_) {
      // Handle upload error
    }
    return null;
  }
}
