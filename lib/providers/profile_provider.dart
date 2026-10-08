import 'package:flutter/material.dart';
import '../models/profile_model.dart';
import '../services/storage_service.dart';

class ProfileProvider extends ChangeNotifier {
  final StorageService _storage;
  List<ProfileModel> _profiles = [];
  String _activeProfileId = 'prof-emms';

  ProfileProvider([StorageService? storage])
      : _storage = storage ?? StorageService.instance {
    _profiles = _storage.loadProfiles();
    _activeProfileId = _storage.loadActiveProfileId();
  }

  List<ProfileModel> get profiles => _profiles;
  String get activeProfileId => _activeProfileId;

  ProfileModel get activeProfile {
    return _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.isNotEmpty ? _profiles.first : defaultProfilesList.first,
    );
  }

  void setActiveProfile(String id) {
    _activeProfileId = id;
    _storage.saveActiveProfileId(id);
    notifyListeners();
  }

  void addProfile(ProfileModel profile) {
    _profiles.add(profile);
    _storage.saveProfiles(_profiles);
    setActiveProfile(profile.id);
  }

  void updateProfile(ProfileModel updated) {
    final idx = _profiles.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _profiles[idx] = updated;
      _storage.saveProfiles(_profiles);
      notifyListeners();
    }
  }

  void deleteProfile(String id) {
    if (_profiles.length <= 1) return; // Prevent deleting last profile
    _profiles.removeWhere((p) => p.id == id);
    _storage.saveProfiles(_profiles);
    if (_activeProfileId == id) {
      setActiveProfile(_profiles.first.id);
    } else {
      notifyListeners();
    }
  }
}
