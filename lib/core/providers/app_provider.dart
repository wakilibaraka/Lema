import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/demo_mode_service.dart';
import '../services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage;
  final ApiService _api;

  int _selectedNavIndex = 0;
  String _activeTab = 'queue';
  String _selectedChannelFilter = 'all';
  bool _isDarkMode = false;
  bool _autoplayVideos = false;
  bool _sidebarCollapsed = false;
  String _daemonStatus = 'ONLINE';

  AppProvider([StorageService? storage, ApiService? api])
    : _storage = storage ?? StorageService.instance,
      _api = api ?? ApiService.instance {
    _isDarkMode = _storage.isDarkMode();
    _autoplayVideos = _storage.autoplayVideos();
    _sidebarCollapsed = _storage.sidebarCollapsed();
    _checkDaemon();
  }

  int get selectedNavIndex => _selectedNavIndex;

  String get activeTab => _activeTab;
  String get selectedChannelFilter => _selectedChannelFilter;
  bool get isDarkMode => _isDarkMode;

  /// Demo mode is owned by [DemoModeService] because the dispatch path and the
  /// demo seed read it directly; this provider only surfaces it to the UI and
  /// republishes changes.
  /// It replaces the separate `sandboxMode` flag, which was a second switch
  /// claiming the same thing ("posts are simulated safely") without any code
  /// behind it.
  bool get demoMode => DemoModeService.isEnabled;
  bool get autoplayVideos => _autoplayVideos;
  bool get sidebarCollapsed => _sidebarCollapsed;

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    _storage.setSidebarCollapsed(_sidebarCollapsed);
    notifyListeners();
  }
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

  /// Hydrates demo mode from storage; called once at startup.
  Future<void> loadDemoMode() async {
    await DemoModeService.load();
    notifyListeners();
  }

  Future<void> setDemoMode(bool enabled) async {
    if (DemoModeService.isEnabled == enabled) return;
    await DemoModeService.setEnabled(enabled);
    notifyListeners();
  }

  /// Video autoplay, persisted. Default OFF.
  void toggleAutoplay() {
    _autoplayVideos = !_autoplayVideos;
    _storage.setAutoplayVideos(_autoplayVideos);
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
