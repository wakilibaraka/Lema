import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';
import 'demo_mode_service.dart';

/// What actually happened when a post was handed to the daemon.
///
/// A `bool` could not express this: it collapsed "the daemon said no" and
/// "nothing is listening on 3001" into the same `false`, and every caller
/// dropped it on the floor.
enum DispatchOutcome {
  /// The daemon accepted the publish request (2xx), or demo mode simulated it.
  sent,

  /// Nothing was published. No daemon answered; the post is still pending.
  offline,

  /// Nothing was published. The daemon answered with a refusal.
  rejected,
}

class DispatchResult {
  final DispatchOutcome outcome;

  /// Human-readable cause, safe to show next to a Retry action.
  final String? detail;

  const DispatchResult(this.outcome, [this.detail]);

  bool get isSent => outcome == DispatchOutcome.sent;

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

  Future<List<PostModel>> fetchPosts() async {
    try {
      final res = await _withRetry(() => _http.get(Uri.parse('$baseUrl/api/posts')).timeout(
            const Duration(seconds: 4),
          ));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => PostModel.fromJson(e)).toList();
      }
    } catch (_) {
      // Local fallback
    }
    return [];
  }

  Future<List<PostModel>> fetchQueue() => fetchPosts();

  Future<bool> checkDaemonStatus() async {
    try {
      final res = await _withRetry(() => _http.get(Uri.parse('$baseUrl/api/settings')).timeout(
            const Duration(seconds: 3),
          ));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Hands [post] to the local daemon and reports the real outcome.
  ///
  /// The publish POST deliberately bypasses [_withRetry]: a timed-out or
  /// 5xx'd publish may already have gone out, so retrying it would post the
  /// same content twice (review finding 2). The dispatch UI owns Retry.
  /// [_withRetry] stays on the GETs, where a repeat is harmless.
  Future<DispatchResult> dispatchPost(PostModel post) => _dispatch(post.id);

  Future<DispatchResult> _dispatch(String postId) async {
    // Demo mode answers locally: no daemon and no platform APIs are touched,
    // which is what the app-review walkthroughs need (TECHNICAL_PLAN §4).
    // The result is labelled so the UI never claims a real send.
    if (DemoModeService.isEnabled) {
      return const DispatchResult(
          DispatchOutcome.sent, 'Demo mode: local publish simulated');
    }

    try {
      final res = await _http
          .post(Uri.parse('$baseUrl/api/posts/$postId/publish'))
          .timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const DispatchResult(DispatchOutcome.sent);
      }
      return DispatchResult(
        DispatchOutcome.rejected,
        'Daemon refused the publish (HTTP ${res.statusCode})',
      );
    } on TimeoutException {
      return const DispatchResult(
          DispatchOutcome.offline, 'Daemon timed out after 6s');
    } on SocketException catch (e) {
      return DispatchResult(DispatchOutcome.offline,
          'Daemon unreachable (${e.osError?.message ?? e.message})');
    } on http.ClientException catch (e) {
      return DispatchResult(
          DispatchOutcome.offline, 'Daemon unreachable (${e.message})');
    } catch (e) {
      return DispatchResult(DispatchOutcome.offline, 'Daemon unreachable ($e)');
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
        headers: {'Content-Type': 'application/json'},
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
