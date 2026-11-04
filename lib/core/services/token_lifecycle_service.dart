import 'package:shared_preferences/shared_preferences.dart';

enum TokenStatus { connected, expiringSoon, expired, neverConnected }

/// What the app knows about its platform connections: status only. The tokens
/// themselves stay in the daemon's keychain.
class TokenLifecycleService {
  static const String _legacyTokensKey = 'lema_platform_tokens';
  static const String _demoKey = 'lema_demo_accounts';

  final Map<String, TokenStatus> _statuses = {};

  bool isConnected(String platform) {
    final s = getStatus(platform);
    return s == TokenStatus.connected || s == TokenStatus.expiringSoon;
  }

  TokenStatus getStatus(String platform) =>
      _statuses[platform] ?? TokenStatus.neverConnected;

  List<String> _where(bool Function(TokenStatus) test) => [
        for (final e in _statuses.entries)
          if (test(e.value)) e.key,
      ];

  List<String> get connectedPlatforms => _where((s) => s != TokenStatus.expired);
  List<String> get expiredPlatforms => _where((s) => s == TokenStatus.expired);
  List<String> get expiringSoonPlatforms =>
      _where((s) => s == TokenStatus.expiringSoon);

  void apply(Map<String, String> statuses) {
    _statuses
      ..clear()
      ..addAll(statuses.map((k, v) => MapEntry(
          k, TokenStatus.values.firstWhere((s) => s.name == v,
              orElse: () => TokenStatus.expired))));
  }

  /// Older versions kept pasted tokens here in plain text. No adapter ever used
  /// them, so they are deleted rather than moved.
  Future<void> deleteLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyTokensKey);
  }

  Future<void> loadDemo() async {
    final prefs = await SharedPreferences.getInstance();
    apply({for (final p in prefs.getStringList(_demoKey) ?? const <String>[]) p: 'connected'});
  }

  Future<void> setDemo(String platform, bool connected) async {
    final prefs = await SharedPreferences.getInstance();
    final list = {...prefs.getStringList(_demoKey) ?? const <String>[]};
    connected ? list.add(platform) : list.remove(platform);
    await prefs.setStringList(_demoKey, list.toList());
    await loadDemo();
  }
}
