import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TokenStatus { connected, expiringSoon, expired, neverConnected }

class PlatformToken {
  final String platform;
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final DateTime connectedAt;

  PlatformToken({
    required this.platform,
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  TokenStatus get status {
    if (expiresAt == null) return TokenStatus.connected;
    final now = DateTime.now();
    final hoursUntilExpiry = expiresAt!.difference(now).inHours;
    if (hoursUntilExpiry <= 0) return TokenStatus.expired;
    if (hoursUntilExpiry <= 24) return TokenStatus.expiringSoon;
    return TokenStatus.connected;
  }

  bool get isExpired => status == TokenStatus.expired;
  bool get needsReconnect => status == TokenStatus.expired;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt?.toIso8601String(),
        'connectedAt': connectedAt.toIso8601String(),
      };

  factory PlatformToken.fromJson(Map<String, dynamic> json) => PlatformToken(
        platform: json['platform'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.tryParse(json['expiresAt'] as String)
            : null,
        connectedAt: json['connectedAt'] != null
            ? DateTime.tryParse(json['connectedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class TokenLifecycleService {
  static const String _storageKey = 'lema_platform_tokens';

  final Map<String, PlatformToken> _tokens = {};

  Map<String, PlatformToken> get tokens => Map.unmodifiable(_tokens);

  PlatformToken? getToken(String platform) => _tokens[platform];

  bool isConnected(String platform) {
    final token = _tokens[platform];
    return token != null && !token.isExpired;
  }

  TokenStatus getStatus(String platform) {
    final token = _tokens[platform];
    if (token == null) return TokenStatus.neverConnected;
    return token.status;
  }

  List<String> get connectedPlatforms =>
      _tokens.entries.where((e) => !e.value.isExpired).map((e) => e.key).toList();

  List<String> get expiredPlatforms =>
      _tokens.entries.where((e) => e.value.isExpired).map((e) => e.key).toList();

  List<String> get expiringSoonPlatforms => _tokens.entries
      .where((e) => e.value.status == TokenStatus.expiringSoon)
      .map((e) => e.key)
      .toList();

  void setToken(PlatformToken token) {
    _tokens[token.platform] = token;
  }

  void removeToken(String platform) {
    _tokens.remove(platform);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _tokens.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_storageKey, encoded);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _tokens.clear();
      decoded.forEach((key, value) {
        _tokens[key] = PlatformToken.fromJson(value as Map<String, dynamic>);
      });
    } catch (_) {}
  }

  Future<void> clear() async {
    _tokens.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
