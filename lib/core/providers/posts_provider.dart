import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/queue_slot_model.dart';
import '../recurrence.dart';
import '../services/queue_autofill_service.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../demo_seed.dart';

class PostsProvider extends ChangeNotifier {
  final StorageService _storage;
  final ApiService _api;

  List<PostModel> _posts = [];
  final List<QueueSlotModel> _queueSlots = defaultQueueSlots;
  PostModel? _activeSimulatorPost;

  // Pre-move snapshot for one-tap undo of grid reorders.
  List<PostModel>? _lastOrderSnapshot;

  bool get canUndoReorder => _lastOrderSnapshot != null;

  // Surfaced when the stored queue failed to decode.
  bool _loadError = false;
  bool get loadError => _loadError;

  PostsProvider([StorageService? storage, ApiService? api])
      : _storage = storage ?? StorageService.instance,
        _api = api ?? ApiService.instance {
    _posts = _storage.loadPosts();
    if (_posts.isEmpty) {
      _posts = List.from(defaultSeedPosts);
      _storage.savePosts(_posts);
    } else if (_storage.postsWereMissing) {
      // First run: the seed queue is what the user is looking at, so it has to
      // be stored. Leaving it unsaved rebuilt the seeds (and their launch-
      // relative slot times) on every start, so the schedule drifted.
      _storage.savePosts(_posts);
    } else {
      // Merge any seed ids missing from storage
      // (e.g. new draft seeds on existing installs), then persist.
      var merged = false;
      for (final seed in defaultSeedPosts) {
        if (!_posts.any((p) => p.id == seed.id)) {
          _posts.add(seed);
          merged = true;
        }
      }
      if (merged) _storage.savePosts(_posts);
    }
    _loadError = _storage.hadPostsDecodeError;
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

  List<PostModel> get failedPosts =>
      _posts.where((p) => p.status == 'failed').toList();

  List<PostModel> get draftPosts =>
      _posts.where((p) => p.status == 'draft').toList();

  /// Scheduled posts in the order they will go out.
  List<PostModel> get queuePosts => scheduledPosts
    ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

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

  /// Reorder the master queue from a filtered-grid drag.
  /// [fromFiltered]/[toFiltered] are indices inside the filtered subset
  /// described by the active Lema filters, so we map them back to
  /// master-list indices before moving.
  void reorderPosts(int fromFiltered, int toFiltered, String platformFilter,
      String statusFilter, String formatFilter) {
    List<PostModel> filtered = _posts.where((p) {
      final platformOk = platformFilter == 'all' ||
          p.platforms.contains(platformFilter) ||
          p.primaryPlatform.name == platformFilter;
      final statusOk =
          statusFilter == 'all' || p.status.toLowerCase() == statusFilter;
      final formatOk = formatFilter == 'all' ||
          (formatFilter == 'video' ? p.isVideo : !p.isVideo);
      return platformOk && statusOk && formatOk;
    }).toList();
    if (fromFiltered < 0 ||
        fromFiltered >= filtered.length ||
        toFiltered < 0 ||
        toFiltered >= filtered.length) {
      return;
    }
    final moved = filtered[fromFiltered];
    final target = filtered[toFiltered];
    final fromMaster = _posts.indexWhere((p) => p.id == moved.id);
    var toMaster = _posts.indexWhere((p) => p.id == target.id);
    if (fromMaster == -1 || toMaster == -1) return;
    _lastOrderSnapshot = List<PostModel>.from(_posts);
    final item = _posts.removeAt(fromMaster);
    // Adjust when removal shifts the target left.
    if (fromMaster < toMaster) toMaster -= 1;
    _posts.insert(toMaster, item);
    _storage.savePosts(_posts);
    notifyListeners();
  }

  /// Gives one post a new time. [undoLastReorder] reverses it.
  void reschedulePost(String id, DateTime when) {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    _lastOrderSnapshot = List<PostModel>.from(_posts);
    updatePost(_posts[idx].copyWith(scheduledTime: when));
  }

  /// Moves a post within [queuePosts]. The slot times stay where they are and
  /// the posts take new ones, so the new order is the order they go out in.
  void reorderQueue(int oldIndex, int newIndex) {
    final queue = queuePosts;
    final times = queue.map((p) => p.scheduledTime).toList();
    _lastOrderSnapshot = List<PostModel>.from(_posts);
    queue.insert(newIndex, queue.removeAt(oldIndex));
    for (var i = 0; i < queue.length; i++) {
      final idx = _posts.indexWhere((p) => p.id == queue[i].id);
      _posts[idx] = queue[i].copyWith(scheduledTime: times[i]);
    }
    _storage.savePosts(_posts);
    notifyListeners();
  }

  /// Schedules drafts into open days at the best hours, returning how many
  /// were placed. [undoLastReorder] reverses it.
  int autoSlotDrafts(List<int> rankedHours) {
    final drafts = draftPosts;
    final times = QueueAutofillService.openSlotTimes(
      now: DateTime.now(),
      count: drafts.length,
      scheduledPosts: scheduledPosts,
      rankedHours: rankedHours,
      fallbackSlots: _queueSlots,
    );
    if (times.isEmpty) return 0;
    _lastOrderSnapshot = List<PostModel>.from(_posts);
    for (var i = 0; i < times.length; i++) {
      final idx = _posts.indexWhere((p) => p.id == drafts[i].id);
      _posts[idx] = drafts[i].copyWith(status: 'scheduled', scheduledTime: times[i]);
    }
    _storage.savePosts(_posts);
    notifyListeners();
    return times.length;
  }

  /// Restores the order snapshotted before the last [reorderPosts].
  void undoLastReorder() {
    if (_lastOrderSnapshot == null) return;
    _posts = List<PostModel>.from(_lastOrderSnapshot!);
    _lastOrderSnapshot = null;
    _storage.savePosts(_posts);
    notifyListeners();
  }

  /// Discards the corrupted cache and restores seed posts.
  Future<void> retryLoad() async {
    await _storage.clearPosts();
    _posts = List.from(defaultSeedPosts);
    _storage.savePosts(_posts);
    _loadError = false;
    notifyListeners();
  }

  /// Hands a post to the daemon and reports what happened.
  /// The post only becomes `published` once the dispatch actually
  /// succeeded. It used to be flipped to `published` *before* the request
  /// and the daemon's answer was discarded, so a dead daemon still emptied
  /// the queue and every failure path in the dispatch UI was unreachable.
  Future<DispatchResult> publishNow(String id) async {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx == -1) {
      return const DispatchResult(DispatchOutcome.rejected, 'Post no longer exists');
    }

    final post = _posts[idx];
    final result = await _api.dispatchPost(post);

    // Re-read: the post may have been edited or deleted while the daemon
    // request was in flight.
    final current = _posts.indexWhere((p) => p.id == id);
    if (current == -1) return result;

    if (!result.isSent) {
      _posts[current] = _posts[current].copyWith(
        status: 'failed',
        failureReason: result.toString(),
      );
      _storage.savePosts(_posts);
      notifyListeners();
      return result;
    }

    final sent = _posts[current];
    final now = DateTime.now();
    _posts[current] = sent.copyWith(
      status: 'published',
      postedAt: now,
      clearFailure: true,
    );
    final next = nextOccurrence(sent, now);
    if (next != null) {
      _posts.insert(
        current,
        sent.copyWith(
          id: '${sent.id}-${now.millisecondsSinceEpoch}',
          status: 'scheduled',
          scheduledTime: next,
          clearFailure: true,
        ),
      );
    }
    _storage.savePosts(_posts);
    notifyListeners();
    return result;
  }

  /// Scheduled posts whose slot has already passed. The daemon is parked, so
  /// nothing converts these on its own — the queue has to surface them.
  List<PostModel> get overduePosts {
    final overdue = _posts.where((p) => p.isOverdue).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return overdue;
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
