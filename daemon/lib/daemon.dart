import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'recurrence_rule.dart';

/// Sends one post. Throws when the platform refused it.
typedef Adapter = Future<void> Function(Map<String, dynamic> post);

/// Proves the flow without touching a platform. Replaced from P4.
Future<void> fakeAdapter(Map<String, dynamic> post) async {
  stdout.writeln('FAKE publish ${post['id']}: nothing left this machine');
}

/// The missed-post rule: up to this late, a post still goes out. Later than
/// this it is held as failed for the user to look at, because a post meant
/// for last night can be wrong today.
const missedAfter = Duration(hours: 1);

const _maxUploadBytes = 256 * 1024 * 1024;

/// Thrown by an adapter when a send may have reached the platform, such as a
/// timeout after the request went out. Such a post is never sent again by itself.
class ResultUnknown implements Exception {
  final String message;
  ResultUnknown(this.message);
  @override
  String toString() => message;
}

class PublishRefused implements Exception {
  final int status;
  final String message;
  PublishRefused(this.status, this.message);
}

class Daemon {
  final Directory home;
  final Adapter adapter;
  final DateTime Function() clock;

  late final String token;
  final Map<String, Map<String, dynamic>> _posts = {};
  HttpServer? _server;
  Timer? _timer;

  Daemon(this.home, this.adapter, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now {
    home.createSync(recursive: true);
    Process.runSync('chmod', ['700', home.path]);
    token = _loadToken();
    _load();
  }

  File get _store => File('${home.path}/posts.json');
  Directory get _uploads => Directory('${home.path}/uploads');

  List<Map<String, dynamic>> get posts => _posts.values.toList();

  String _loadToken() {
    final file = File('${home.path}/token');
    if (file.existsSync()) return file.readAsStringSync().trim();
    final rng = Random.secure();
    final value = List.generate(
        32, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    file.createSync();
    Process.runSync('chmod', ['600', file.path]);
    file.writeAsStringSync(value, flush: true);
    return value;
  }

  void _load() {
    // A corrupt store throws here on purpose: starting empty would lose the
    // record of what was already sent, and could send it again.
    if (_store.existsSync()) {
      for (final p in jsonDecode(_store.readAsStringSync()) as List) {
        _posts[p['id'] as String] = Map<String, dynamic>.from(p as Map);
      }
    }
    // Claimed but never finished: the send may or may not have gone out, so
    // it must not be repeated.
    var changed = false;
    for (final p in _posts.values) {
      if (p['status'] == 'sending') {
        p['status'] = 'unknown';
        p['failureReason'] =
            'The daemon stopped during this send. Check the platform before retrying.';
        changed = true;
      }
    }
    if (changed) _save();
  }

  void _save() {
    final tmp = File('${_store.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(posts), flush: true);
    tmp.renameSync(_store.path);
  }

  /// Fires everything due. The claim is written to disk before the adapter
  /// runs, so no crash or second tick can send a post twice.
  Future<void> tick() async {
    final now = clock();
    final due = <Map<String, dynamic>>[];
    var changed = false;
    for (final p in _posts.values) {
      if (p['status'] != 'scheduled') continue;
      final at = DateTime.tryParse('${p['scheduledTime']}');
      if (at == null) {
        p['status'] = 'failed';
        p['failureReason'] = 'This post has no readable schedule time.';
        changed = true;
      } else if (now.difference(at) > missedAfter) {
        p['status'] = 'failed';
        p['failureReason'] =
            'Missed its slot by over an hour while the daemon was off or asleep. Not sent.';
        changed = true;
      } else if (!at.isAfter(now)) {
        p['status'] = 'sending';
        due.add(p);
        changed = true;
      }
    }
    if (changed) _save();
    for (final p in due) {
      if (await _send(p)) _queueNext(p);
    }
  }

  Future<bool> _send(Map<String, dynamic> p) async {
    try {
      await adapter(p);
      p['status'] = 'published';
      p['postedAt'] = clock().toIso8601String();
      p['failureReason'] = null;
      _save();
      return true;
    } on ResultUnknown catch (e) {
      p['status'] = 'unknown';
      p['failureReason'] = '$e Check the platform before sending again.';
      _save();
      return false;
    } catch (e) {
      p['status'] = 'failed';
      p['failureReason'] = '$e';
      _save();
      return false;
    }
  }

  void _queueNext(Map<String, dynamic> p) {
    final now = clock();
    final next = nextSlot(
      DateTime.parse('${p['scheduledTime']}'),
      '${p['recurrence'] ?? 'none'}',
      List<int>.from(p['recurrenceDays'] as List? ?? const []),
      now,
    );
    if (next == null) return;
    final id = '${p['id']}-${now.millisecondsSinceEpoch}';
    _posts[id] = {
      ...p,
      'id': id,
      'status': 'scheduled',
      'scheduledTime': next.toIso8601String(),
      'scheduledDate': next.toIso8601String().split('T').first,
      'postedAt': null,
      'createdByDaemon': true,
    };
    _save();
  }

  /// Share Now. The app queues the next repeat itself, so this one doesn't.
  Future<void> publishNow(String id, Map<String, dynamic> post) async {
    final status = _posts[id]?['status'];
    if (status == 'sending' || status == 'published') {
      throw PublishRefused(409, 'This post was already sent');
    }
    final confirmed = post.remove('confirmedNotPosted') == true;
    if (status == 'unknown' && !confirmed) {
      throw PublishRefused(
          409, 'This post may already be out. Check the platform first');
    }
    final p = {...post, 'id': id, 'status': 'sending', 'manual': true};
    _posts[id] = p;
    _save();
    if (!await _send(p)) {
      throw PublishRefused(
          p['status'] == 'unknown' ? 504 : 502, '${p['failureReason']}');
    }
  }

  /// Makes the daemon's queue match the app's. [scheduled] is the app's whole
  /// scheduled list and [knownIds] every post it holds, so a post edited or
  /// deleted while the daemon was off is still caught. The answer has what
  /// the daemon did for the app to merge.
  List<Map<String, dynamic>> sync(
      List<Map<String, dynamic>> scheduled, Set<String> knownIds) {
    final incoming = {for (final p in scheduled) p['id'] as String: p};
    for (final id in _posts.keys.toList()) {
      final p = _posts[id]!;
      if (p['status'] == 'sending') continue;
      final known = knownIds.contains(id) || incoming.containsKey(id);
      final unseenRepeat = p['createdByDaemon'] == true && !known;
      if (unseenRepeat) continue;
      if (known) p.remove('createdByDaemon');
      final wanted = incoming[id];
      if (p['status'] == 'scheduled') {
        if (wanted == null) _posts.remove(id);
      } else if (!known) {
        _posts.remove(id); // Deleted in the app; drop the history.
      }
    }
    for (final entry in incoming.entries) {
      final existing = _posts[entry.key];
      final status = existing?['status'];
      if (status == 'sending' || status == 'published') continue;
      // The app's copy of these is stale until the user picks a new time.
      if ((status == 'failed' || status == 'unknown') &&
          existing!['scheduledTime'] == entry.value['scheduledTime']) {
        continue;
      }
      _posts[entry.key] = entry.value;
    }
    _save();
    return posts;
  }

  Future<void> serve({int port = 3001, Duration every = const Duration(seconds: 15)}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _timer = Timer.periodic(every, (_) => tick());
    unawaited(tick());
    _server!.listen(_handle);
  }

  int get port => _server!.port;

  Future<void> close() async {
    _timer?.cancel();
    await _server?.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final parts = req.uri.pathSegments;
    try {
      if (req.method == 'GET' && parts.length == 2 && parts[0] == 'uploads') {
        return await _serveUpload(parts[1], res);
      }
      if (req.headers.value('x-lema-token') != token) {
        return _json(res, 401, {'error': 'Missing or wrong token'});
      }
      final route = '${req.method} ${parts.length > 1 ? parts.sublist(1).join('/') : ''}';
      if (route == 'GET settings') {
        return _json(res, 200, {'adapter': 'fake'});
      } else if (route == 'GET posts') {
        return _json(res, 200, posts);
      } else if (route == 'POST posts/sync') {
        final body = await _body(req);
        final synced = sync(
          [for (final p in body['posts'] as List) Map<String, dynamic>.from(p as Map)],
          Set<String>.from(body['ids'] as List),
        );
        return _json(res, 200, synced);
      } else if (req.method == 'POST' &&
          parts.length == 4 &&
          parts[1] == 'posts' &&
          parts[3] == 'publish') {
        await publishNow(parts[2], await _body(req));
        return _json(res, 200, {'status': 'published'});
      } else if (req.method == 'GET' && parts.length == 3 && parts[1] == 'analytics') {
        // No platform numbers exist yet. The app shows its stored counts.
        return _json(res, 404, {'error': 'Analytics unavailable'});
      } else if (route == 'POST upload') {
        return await _upload(req);
      }
      return _json(res, 404, {'error': 'No such route'});
    } on PublishRefused catch (e) {
      return _json(res, e.status, {'error': e.message});
    } on FormatException catch (e) {
      return _json(res, 400, {'error': e.message});
    } on TypeError {
      return _json(res, 400, {'error': 'Malformed request'});
    }
  }

  Future<Map<String, dynamic>> _body(HttpRequest req) async {
    final bytes = await req.fold<List<int>>([], (all, chunk) {
      if (all.length + chunk.length > _maxUploadBytes * 2) {
        throw const FormatException('Request too large');
      }
      return all..addAll(chunk);
    });
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<void> _upload(HttpRequest req) async {
    final body = await _body(req);
    final data = '${body['data']}';
    final bytes = base64Decode(data.substring(data.indexOf(',') + 1));
    if (bytes.length > _maxUploadBytes) {
      throw const FormatException('File too large');
    }
    final ext = RegExp(r'\.([a-zA-Z0-9]{1,8})$').firstMatch('${body['name']}')?.group(1) ?? 'bin';
    final rng = Random.secure();
    final name = '${List.generate(16, (_) => rng.nextInt(16).toRadixString(16)).join()}.$ext';
    _uploads.createSync(recursive: true);
    await File('${_uploads.path}/$name').writeAsBytes(bytes, flush: true);
    final path = '/uploads/$name';
    return _json(req.response, 200, {'fileUrl': path, 'url': 'http://localhost:$port$path'});
  }

  // Tokenless because media players can't send headers. Names are random and
  // the server only listens on loopback.
  Future<void> _serveUpload(String name, HttpResponse res) async {
    final file = File('${_uploads.path}/$name');
    if (!RegExp(r'^[0-9a-f]{16}\.[a-zA-Z0-9]+$').hasMatch(name) || !file.existsSync()) {
      return _json(res, 404, {'error': 'No such file'});
    }
    await res.addStream(file.openRead());
    await res.close();
  }

  Future<void> _json(HttpResponse res, int status, Object body) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    await res.close();
  }
}
