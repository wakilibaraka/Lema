import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_asset.dart';
import '../models/profile_model.dart';
import '../models/post_model.dart';
import '../demo_seed.dart';

class StorageService {
  static const String _keyProfiles = 'lema_profiles';
  static const String _keyActiveProfileId = 'lema_active_profile_id';
  static const String _keyPosts = 'lema_posts';
  static const String _keyAssets = 'lema_media_assets';
  static const String _keyThemeMode = 'lema_theme_mode';
  static const String _keyAutoplay = 'lema_video_autoplay';
  static const String _keySidebarCollapsed = 'lema_sidebar_collapsed';

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
  // Decode failures are surfaced (not silently swallowed) so the
  // UI can show an on-brand error card with a reset action.
  bool _postsDecodeError = false;
  bool get hadPostsDecodeError => _postsDecodeError;

  /// True when nothing was stored for posts, so the caller can persist the
  /// seed queue. The seed slots are built relative to launch time, so leaving
  /// them unsaved moved the whole visible schedule on every restart.
  bool _postsWereMissing = false;
  bool get postsWereMissing => _postsWereMissing;

  List<PostModel> loadPosts() {
    final raw = _prefs.getString(_keyPosts);
    if (raw == null || raw.isEmpty) {
      _postsDecodeError = false;
      _postsWereMissing = true;
      // Return a COPY — callers mutate the list (add,
      // reorder, migrate) and must never corrupt the seed template.
      return List<PostModel>.from(defaultSeedPosts);
    }
    try {
      final List decoded = jsonDecode(raw);
      _postsDecodeError = false;
      _postsWereMissing = false;
      return decoded.map((e) => PostModel.fromJson(e)).toList();
    } catch (_) {
      // A corrupt blob is not an empty one: never overwrite it here, the
      // retry path in the grid owns recovery.
      _postsDecodeError = true;
      _postsWereMissing = false;
      return List<PostModel>.from(defaultSeedPosts);
    }
  }

  Future<void> savePosts(List<PostModel> posts) async {
    final encoded = jsonEncode(posts.map((p) => p.toJson()).toList());
    await _prefs.setString(_keyPosts, encoded);
  }

  Future<void> clearPosts() async {
    await _prefs.remove(_keyPosts);
  }


  // --- Media vault ---
  /// Null when nothing usable is stored, so the caller can use the seed.
  List<MediaAsset>? loadAssets() {
    final raw = _prefs.getString(_keyAssets);
    if (raw == null || raw.isEmpty) return null;
    try {
      final List decoded = jsonDecode(raw);
      return decoded.map((e) => MediaAsset.fromJson(e)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAssets(List<MediaAsset> assets) async {
    await _prefs.setString(_keyAssets, jsonEncode(assets.map((a) => a.toJson()).toList()));
  }

  // --- Theme Mode ---
  bool isDarkMode() {
    return _prefs.getBool(_keyThemeMode) ?? false;
  }

  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_keyThemeMode, isDark);
  }

  // --- Video autoplay ---
  /// Default OFF: feeds stay silent until the user enables motion.
  bool autoplayVideos() {
    return _prefs.getBool(_keyAutoplay) ?? false;
  }

  Future<void> setAutoplayVideos(bool enabled) async {
    await _prefs.setBool(_keyAutoplay, enabled);
  }

  bool sidebarCollapsed() => _prefs.getBool(_keySidebarCollapsed) ?? false;

  Future<void> setSidebarCollapsed(bool collapsed) async {
    await _prefs.setBool(_keySidebarCollapsed, collapsed);
  }
}
