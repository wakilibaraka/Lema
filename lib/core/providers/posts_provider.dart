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

  /// Posts that may or may not have gone out, waiting on the user to check.
  List<PostModel> get unknownPosts =>
      _posts.where((p) => p.status == 'unknown').toList();

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
    _persist();
    _activeSimulatorPost = post;
    notifyListeners();
  }

  void updatePost(PostModel updated) {
    final idx = _posts.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _posts[idx] = updated;
      _persist();
      if (_activeSimulatorPost?.id == updated.id) {
        _activeSimulatorPost = updated;
      }
      notifyListeners();
    }
  }

  void deletePost(String id) {
    _posts.removeWhere((p) => p.id == id);
    _persist();
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
    _persist();
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
    _persist();
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
    _persist();
    notifyListeners();
    return times.length;
  }

  /// Restores the order snapshotted before the last [reorderPosts].
  void undoLastReorder() {
    if (_lastOrderSnapshot == null) return;
    _posts = List<PostModel>.from(_lastOrderSnapshot!);
    _lastOrderSnapshot = null;
    _persist();
    notifyListeners();
  }

  /// Discards the corrupted cache and restores seed posts.
  Future<void> retryLoad() async {
    await _storage.clearPosts();
    _posts = List.from(defaultSeedPosts);
    _persist();
    _loadError = false;
    notifyListeners();
  }

  /// Hands a post to the daemon and reports what happened.
  /// The post only becomes `published` once the dispatch actually
  /// succeeded. It used to be flipped to `published` *before* the request
  /// and the daemon's answer was discarded, so a dead daemon still emptied
  /// the queue and every failure path in the dispatch UI was unreachable.
  Future<DispatchResult> publishNow(String id,
      {bool confirmedNotPosted = false}) async {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx == -1) {
      return const DispatchResult(DispatchOutcome.failed, 'Post no longer exists');
    }

    final result = await _api.dispatchPost(_posts[idx],
        confirmedNotPosted: confirmedNotPosted);

    // Re-read: the post may have been edited or deleted while the daemon
    // request was in flight.
    final current = _posts.indexWhere((p) => p.id == id);
    if (current == -1) return result;

    if (result.isPublished) {
      _markPublished(current);
    } else {
      _posts[current] = _posts[current].copyWith(
        status: result.outcome.name,
        failureReason: result.toString(),
      );
    }
    _persist();
    notifyListeners();
    return result;
  }

  /// The user checked the platform and found an unknown post did go out.
  void confirmPosted(String id) {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    _markPublished(idx);
    _persist();
    notifyListeners();
  }

  void _markPublished(int idx) {
    final sent = _posts[idx];
    final now = DateTime.now();
    _posts[idx] = sent.copyWith(
      status: 'published',
      postedAt: now,
      clearFailure: true,
    );
    final next = nextOccurrence(sent, now);
    if (next != null) {
      _posts.insert(
        idx,
        sent.copyWith(
          id: '${sent.id}-${now.millisecondsSinceEpoch}',
          status: 'scheduled',
          scheduledTime: next,
          clearFailure: true,
        ),
      );
    }
  }

  /// Scheduled posts whose slot has already passed. The daemon only fires
  /// while this machine is awake, so the queue still has to surface them.
  List<PostModel> get overduePosts {
    final overdue = _posts.where((p) => p.isOverdue).toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return overdue;
  }

  void _persist() {
    _storage.savePosts(_posts);
    syncWithBackend();
  }

  bool _syncing = false;
  bool _syncAgain = false;

  /// Pushes the queue to the daemon and merges back what it did. Local posts
  /// are the source of truth except for a scheduled or unknown post the daemon
  /// has a result for, and repeats it queued that the app hasn't seen.
  Future<void> syncWithBackend() async {
    // A failed load shows seeds, which must not replace the daemon's queue.
    if (_loadError) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    final remote = await _api.syncPosts(_posts);
    _syncing = false;
    if (remote != null && _merge(remote)) {
      _storage.savePosts(_posts);
      notifyListeners();
    }
    if (_syncAgain) {
      _syncAgain = false;
      await syncWithBackend();
    }
  }

  bool _merge(List<Map<String, dynamic>> remote) {
    var changed = false;
    for (final json in remote) {
      final post = PostModel.fromJson(json);
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx == -1) {
        if (json['createdByDaemon'] == true) {
          _posts.insert(0, post);
          changed = true;
        }
      } else if (_posts[idx].status == 'scheduled' &&
          const ['published', 'failed', 'unknown'].contains(post.status)) {
        _posts[idx] = post;
        changed = true;
      } else if (_posts[idx].status == 'unknown' &&
          const ['published', 'failed'].contains(post.status)) {
        // A Share Now that timed out here but finished there. The daemon
        // leaves its repeat to the app in that case.
        final local = _posts[idx];
        if (post.status == 'published' && json['manual'] == true) {
          _markPublished(idx);
        } else {
          _posts[idx] = post.copyWith(recurrence: local.recurrence);
        }
        changed = true;
      } else if (_posts[idx].status == 'published' &&
          _posts[idx].postUrl == null &&
          post.postUrl != null) {
        // A Share Now's link arrives on the next sync.
        _posts[idx] = _posts[idx].copyWith(postUrl: post.postUrl);
        changed = true;
      }
    }
    return changed;
  }
}
