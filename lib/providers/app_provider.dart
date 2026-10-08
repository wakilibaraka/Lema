import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage;
  final ApiService _api;

  int _selectedNavIndex = 0;
  String _activeTab = 'queue';
  String _selectedChannelFilter = 'all';
  bool _isDarkMode = false;
  bool _sandboxMode = true;
  String _daemonStatus = 'ONLINE';

  AppProvider([StorageService? storage, ApiService? api])
      : _storage = storage ?? StorageService.instance,
        _api = api ?? ApiService.instance {
    _isDarkMode = _storage.isDarkMode();
    _checkDaemon();
  }

  int get selectedNavIndex => _selectedNavIndex;
  String get activeTab => _activeTab;
  String get selectedChannelFilter => _selectedChannelFilter;
  bool get isDarkMode => _isDarkMode;
  bool get sandboxMode => _sandboxMode;
  String get daemonStatus => _daemonStatus;
  bool get isDaemonOnline => _daemonStatus == 'ONLINE';
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void setNavIndex(int index) {
    if (_selectedNavIndex != index) {
      _selectedNavIndex = index;
      notifyListeners();
    }
  }

  void setActiveTab(String tab) {
    if (_activeTab != tab) {
      _activeTab = tab;
      notifyListeners();
    }
  }

  void setChannelFilter(String filter) {
    _selectedChannelFilter = filter;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _storage.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  void toggleSandbox() {
    _sandboxMode = !_sandboxMode;
    notifyListeners();
  }

  Future<void> _checkDaemon() async {
    _daemonStatus = 'CHECKING';
    notifyListeners();
    final ok = await _api.checkDaemonStatus();
    _daemonStatus = ok ? 'ONLINE' : 'SANDBOX';
    notifyListeners();
  }

  Future<void> checkDaemonHealth() async {
    await _checkDaemon();
  }

  Future<void> refreshDaemon() async {
    await _checkDaemon();
  }
}
