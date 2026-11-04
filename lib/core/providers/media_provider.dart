import 'package:flutter/material.dart';

import '../demo_seed.dart';
import '../models/media_asset.dart';
import '../services/storage_service.dart';

class MediaProvider extends ChangeNotifier {
  final StorageService _storage;
  late List<MediaAsset> _assets;

  MediaProvider([StorageService? storage]) : _storage = storage ?? StorageService.instance {
    _assets = _storage.loadAssets() ?? List<MediaAsset>.from(defaultSeedAssets);
  }

  /// Newest first.
  List<MediaAsset> get assets =>
      List.unmodifiable(_assets.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt)));

  List<String> get allTags => (_assets.expand((a) => a.tags).toSet().toList()..sort());

  void add(MediaAsset asset) => _commit([..._assets, asset]);

  void remove(String id) => _commit(_assets.where((a) => a.id != id).toList());

  void setTags(String id, List<String> tags) =>
      _commit([for (final a in _assets) a.id == id ? a.copyWith(tags: tags) : a]);

  void _commit(List<MediaAsset> next) {
    _assets = next;
    _storage.saveAssets(_assets);
    notifyListeners();
  }
}
