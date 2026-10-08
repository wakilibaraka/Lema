import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/queue_slot_model.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class PostsProvider extends ChangeNotifier {
  final StorageService _storage;
  final ApiService _api;

  List<PostModel> _posts = [];
  final List<QueueSlotModel> _queueSlots = defaultQueueSlots;
  PostModel? _activeSimulatorPost;

  PostsProvider([StorageService? storage, ApiService? api])
      : _storage = storage ?? StorageService.instance,
        _api = api ?? ApiService.instance {
    _posts = _storage.loadPosts();
    if (_posts.isEmpty) {
      _posts = List.from(defaultSeedPosts);
      _storage.savePosts(_posts);
    }
    _activeSimulatorPost = _posts.first;
    syncWithBackend();
  }

  List<PostModel> get posts => _posts;
  List<QueueSlotModel> get queueSlots => _queueSlots;
  PostModel? get activeSimulatorPost => _activeSimulatorPost;

  List<PostModel> get scheduledPosts =>
      _posts.where((p) => p.status == 'scheduled').toList();

  List<PostModel> get publishedPosts =>
      _posts.where((p) => p.status == 'published' || p.status == 'posted').toList();

  List<PostModel> get postedPosts => publishedPosts;

  List<PostModel> filterPostsByChannel(String channel) {
    if (channel == 'all') return _posts;
    return _posts.where((p) => p.platforms.contains(channel)).toList();
  }

  void setActiveSimulatorPost(PostModel post) {
    _activeSimulatorPost = post;
    notifyListeners();
  }

  void addPost(PostModel post) {
    _posts.insert(0, post);
    _storage.savePosts(_posts);
    _activeSimulatorPost = post;
    notifyListeners();
  }

  void updatePost(PostModel updated) {
    final idx = _posts.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _posts[idx] = updated;
      _storage.savePosts(_posts);
      if (_activeSimulatorPost?.id == updated.id) {
        _activeSimulatorPost = updated;
      }
      notifyListeners();
    }
  }

  void deletePost(String id) {
    _posts.removeWhere((p) => p.id == id);
    _storage.savePosts(_posts);
    if (_activeSimulatorPost?.id == id && _posts.isNotEmpty) {
      _activeSimulatorPost = _posts.first;
    }
    notifyListeners();
  }

  Future<void> publishNow(String id) async {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final post = _posts[idx];
      final updated = post.copyWith(
        status: 'published',
        postedAt: DateTime.now(),
      );
      _posts[idx] = updated;
      _storage.savePosts(_posts);
      notifyListeners();

      // Dispatch to backend daemon
      try {
        await _api.publishPost(updated);
      } catch (_) {}
    }
  }

  Future<void> syncWithBackend() async {
    try {
      final remote = await _api.fetchQueue();
      if (remote.isNotEmpty) {
        _posts = remote;
        _storage.savePosts(_posts);
        notifyListeners();
      }
    } catch (_) {}
  }
}
