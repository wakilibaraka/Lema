import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';

class ApiService {
  final String baseUrl;
  static ApiService? _instance;

  const ApiService({this.baseUrl = 'http://localhost:3001'});

  static ApiService get instance => _instance ??= const ApiService();

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 1);

  Future<http.Response> _withRetry(Future<http.Response> Function() request) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await request();
        if (response.statusCode == 429 || response.statusCode >= 500) {
          if (attempt < _maxRetries) {
            final jitter = Random().nextInt(1000);
            final delay = _baseDelay * (1 << attempt) + Duration(milliseconds: jitter);
            await Future.delayed(delay);
            continue;
          }
        }
        return response;
      } catch (e) {
        if (attempt < _maxRetries) {
          final jitter = Random().nextInt(1000);
          final delay = _baseDelay * (1 << attempt) + Duration(milliseconds: jitter);
          await Future.delayed(delay);
        } else {
          rethrow;
        }
      }
    }
    throw Exception('Max retries exceeded');
  }

  Future<List<PostModel>> fetchPosts() async {
    try {
      final res = await _withRetry(() => http.get(Uri.parse('$baseUrl/api/posts')).timeout(
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
      final res = await _withRetry(() => http.get(Uri.parse('$baseUrl/api/settings')).timeout(
            const Duration(seconds: 3),
          ));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> triggerShareNow(String postId) async {
    try {
      final res = await _withRetry(() => http.post(
        Uri.parse('$baseUrl/api/posts/$postId/publish'),
      ).timeout(const Duration(seconds: 6)));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> publishPost(PostModel post) => triggerShareNow(post.id);

  Future<String?> uploadMedia({
    required String name,
    required String base64Data,
    required String mimeType,
  }) async {
    try {
      final res = await _withRetry(() => http.post(
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
