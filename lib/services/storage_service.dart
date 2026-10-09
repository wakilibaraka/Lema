import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';
import '../models/post_model.dart';
import '../models/task_model.dart';
import '../models/script_model.dart';

class StorageService {
  static const String _keyProfiles = 'lema_profiles';
  static const String _keyActiveProfileId = 'lema_active_profile_id';
  static const String _keyPosts = 'lema_posts';
  static const String _keyTasks = 'lema_tasks';
  static const String _keyScripts = 'lema_scripts';
  static const String _keyThemeMode = 'lema_theme_mode';

  final SharedPreferences _prefs;
  static StorageService? _instance;

  StorageService(this._prefs) {
    _instance = this;
  }

  static StorageService get instance {
    if (_instance == null) {
      throw StateError('StorageService not initialized. Call init() first.');
    }
    return _instance!;
  }

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = StorageService(prefs);
    return _instance!;
  }

  // --- Profiles ---
  List<ProfileModel> loadProfiles() {
    final raw = _prefs.getString(_keyProfiles);
    if (raw == null || raw.isEmpty) {
      return defaultProfilesList;
    }
    try {
      final List decoded = jsonDecode(raw);
      final list = decoded.map((e) => ProfileModel.fromJson(e)).toList();
      if (!list.any((p) => p.id == 'prof-emms')) {
        return [defaultProfilesList.first, ...list];
      }
      return list;
    } catch (_) {
      return defaultProfilesList;
    }
  }

  Future<void> saveProfiles(List<ProfileModel> profiles) async {
    final encoded = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(_keyProfiles, encoded);
  }

  String loadActiveProfileId() {
    return _prefs.getString(_keyActiveProfileId) ?? 'prof-emms';
  }

  Future<void> saveActiveProfileId(String id) async {
    await _prefs.setString(_keyActiveProfileId, id);
  }

  // --- Posts ---
  // Slice 10: decode failures are surfaced (not silently swallowed) so the
  // UI can show an on-brand error card with a reset action.
  bool _postsDecodeError = false;
  bool get hadPostsDecodeError => _postsDecodeError;

  List<PostModel> loadPosts() {
    final raw = _prefs.getString(_keyPosts);
    if (raw == null || raw.isEmpty) {
      _postsDecodeError = false;
      return defaultSeedPosts;
    }
    try {
      final List decoded = jsonDecode(raw);
      _postsDecodeError = false;
      return decoded.map((e) => PostModel.fromJson(e)).toList();
    } catch (_) {
      _postsDecodeError = true;
      return defaultSeedPosts;
    }
  }

  Future<void> savePosts(List<PostModel> posts) async {
    final encoded = jsonEncode(posts.map((p) => p.toJson()).toList());
    await _prefs.setString(_keyPosts, encoded);
  }

  Future<void> clearPosts() async {
    await _prefs.remove(_keyPosts);
  }

  // --- Tasks ---
  List<TaskModel> loadTasks() {
    final raw = _prefs.getString(_keyTasks);
    if (raw == null || raw.isEmpty) {
      return defaultTasksList;
    }
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => TaskModel.fromJson(e)).toList();
    } catch (_) {
      return defaultTasksList;
    }
  }

  Future<void> saveTasks(List<TaskModel> tasks) async {
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await _prefs.setString(_keyTasks, encoded);
  }

  // --- Scripts ---
  List<ScriptModel> loadScripts() {
    final raw = _prefs.getString(_keyScripts);
    if (raw == null || raw.isEmpty) {
      return defaultScriptsList;
    }
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => ScriptModel.fromJson(e)).toList();
    } catch (_) {
      return defaultScriptsList;
    }
  }

  Future<void> saveScripts(List<ScriptModel> scripts) async {
    final encoded = jsonEncode(scripts.map((s) => s.toJson()).toList());
    await _prefs.setString(_keyScripts, encoded);
  }

  // --- Theme Mode ---
  bool isDarkMode() {
    return _prefs.getBool(_keyThemeMode) ?? false;
  }

  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_keyThemeMode, isDark);
  }
}
