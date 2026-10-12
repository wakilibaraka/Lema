import 'package:flutter/material.dart';
import '../services/token_lifecycle_service.dart';
import '../models/platform_info.dart';

class AuthProvider extends ChangeNotifier {
  final TokenLifecycleService _tokenService;

  AuthProvider({TokenLifecycleService? tokenService})
      : _tokenService = tokenService ?? TokenLifecycleService();

  TokenLifecycleService get tokenService => _tokenService;

  Map<String, TokenStatus> get platformStatuses {
    final statuses = <String, TokenStatus>{};
    for (final platform in platformsMap.keys) {
      statuses[platform] = _tokenService.getStatus(platform);
    }
    return statuses;
  }

  bool isConnected(String platform) => _tokenService.isConnected(platform);

  TokenStatus getStatus(String platform) => _tokenService.getStatus(platform);

  List<String> get connectedPlatforms => _tokenService.connectedPlatforms;
  List<String> get expiredPlatforms => _tokenService.expiredPlatforms;
  List<String> get expiringSoonPlatforms => _tokenService.expiringSoonPlatforms;

  bool get hasAnyExpired => _tokenService.expiredPlatforms.isNotEmpty;
  bool get hasExpiringSoon => _tokenService.expiringSoonPlatforms.isNotEmpty;

  List<String> get platformsWithExpiringPosts {
    return _tokenService.expiredPlatforms;
  }

  Future<void> connectPlatform(String platform, {
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    final token = PlatformToken(
      platform: platform,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
    _tokenService.setToken(token);
    await _tokenService.save();
    notifyListeners();
  }

  Future<void> disconnectPlatform(String platform) async {
    _tokenService.removeToken(platform);
    await _tokenService.save();
    notifyListeners();
  }

  Future<void> refreshToken(String platform, {
    required String newAccessToken,
    String? newRefreshToken,
    DateTime? newExpiresAt,
  }) async {
    final existing = _tokenService.getToken(platform);
    final token = PlatformToken(
      platform: platform,
      accessToken: newAccessToken,
      refreshToken: newRefreshToken ?? existing?.refreshToken,
      expiresAt: newExpiresAt ?? existing?.expiresAt,
      connectedAt: existing?.connectedAt,
    );
    _tokenService.setToken(token);
    await _tokenService.save();
    notifyListeners();
  }

  Future<void> loadTokens() async {
    await _tokenService.load();
    notifyListeners();
  }

  String? getAccessToken(String platform) {
    return _tokenService.getToken(platform)?.accessToken;
  }

  bool canPublishTo(String platform) {
    return _tokenService.isConnected(platform);
  }

  List<String> getDisconnectedPlatforms(List<String> targetPlatforms) {
    return targetPlatforms.where((p) => !isConnected(p)).toList();
  }
}
