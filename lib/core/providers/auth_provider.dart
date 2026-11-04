import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/demo_mode_service.dart';
import '../services/token_lifecycle_service.dart';

class AuthProvider extends ChangeNotifier {
  final TokenLifecycleService _tokenService;
  final ApiService _api;

  AuthProvider({TokenLifecycleService? tokenService, ApiService? api})
      : _tokenService = tokenService ?? TokenLifecycleService(),
        _api = api ?? ApiService.instance;

  bool isConnected(String platform) => _tokenService.isConnected(platform);

  TokenStatus getStatus(String platform) => _tokenService.getStatus(platform);

  List<String> get connectedPlatforms => _tokenService.connectedPlatforms;
  List<String> get expiredPlatforms => _tokenService.expiredPlatforms;
  List<String> get expiringSoonPlatforms => _tokenService.expiringSoonPlatforms;

  bool get hasAnyExpired => _tokenService.expiredPlatforms.isNotEmpty;
  bool get hasExpiringSoon => _tokenService.expiringSoonPlatforms.isNotEmpty;

  /// Reads statuses. With no daemon the last known ones stay on screen.
  Future<void> loadTokens() async {
    await _tokenService.deleteLegacyTokens();
    if (DemoModeService.isEnabled) {
      await _tokenService.loadDemo();
    } else {
      final accounts = await _api.fetchAccounts();
      if (accounts == null) return;
      _tokenService.apply(accounts);
    }
    notifyListeners();
  }

  /// The browser sign-in URL, or why there isn't one. Demo mode connects
  /// directly and returns neither.
  Future<({String? url, String? error})> startConnect(String platform) async {
    if (DemoModeService.isEnabled) {
      await _tokenService.setDemo(platform, true);
      notifyListeners();
      return (url: null, error: null);
    }
    return _api.startConnect(platform);
  }

  /// Watches for the browser sign-in to finish, for up to two minutes.
  Future<void> waitForConnection(String platform) async {
    for (var i = 0; i < 40 && !isConnected(platform); i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      await loadTokens();
    }
  }

  /// False when the daemon couldn't be told, so the connection still stands.
  Future<bool> disconnectPlatform(String platform) async {
    if (DemoModeService.isEnabled) {
      await _tokenService.setDemo(platform, false);
    } else {
      if (!await _api.disconnectAccount(platform)) return false;
      await loadTokens();
    }
    notifyListeners();
    return true;
  }
}
