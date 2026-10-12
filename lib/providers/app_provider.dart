import 'package:flutter/material.dart';
import '../models/nav_destination.dart';
import '../models/simulation_model.dart';
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
  bool _autoplayVideos = false;
  String _daemonStatus = 'ONLINE';
  SimulationViewMode _simulationView = SimulationViewMode.list;

  AppProvider([StorageService? storage, ApiService? api])
      : _storage = storage ?? StorageService.instance,
        _api = api ?? ApiService.instance {
    _isDarkMode = _storage.isDarkMode();
    _autoplayVideos = _storage.autoplayVideos();
    _simulationView = _storage.loadSimulationViewMode();
    _checkDaemon();
  }

  int get selectedNavIndex => _selectedNavIndex;

  /// Which dock tab should read as selected, or -1 when the active screen is
  /// not one of the docked tabs (Composer, Analytics, Settings, …).
  ///
  /// The mobile shell used to clamp every out-of-range index to 0, so the dock
  /// highlighted Home while Settings was on screen.
  int get selectedTabIndex =>
      _selectedNavIndex < lemaDockTabCount ? _selectedNavIndex : -1;
  String get activeTab => _activeTab;
  String get selectedChannelFilter => _selectedChannelFilter;
  bool get isDarkMode => _isDarkMode;
  bool get sandboxMode => _sandboxMode;
  bool get autoplayVideos => _autoplayVideos;
  String get daemonStatus => _daemonStatus;
  bool get isDaemonOnline => _daemonStatus == 'ONLINE';
  SimulationViewMode get simulationView => _simulationView;
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

  /// Slice 25: grid/list presentation for the offline simulation engine,
  /// persisted so the choice survives a restart.
  void setSimulationView(SimulationViewMode mode) {
    if (_simulationView == mode) return;
    _simulationView = mode;
    _storage.setSimulationViewMode(mode);
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

  /// Slice 22: video autoplay, persisted. Default OFF.
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
