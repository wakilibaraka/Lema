import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'accounts.dart';
import 'daemon.dart';

typedef Answer = ({int status, Map<String, String> headers, String body});

/// One HTTP call. Injectable so tests never reach a platform.
typedef Send = Future<Answer> Function(
    String method, Uri url, Map<String, String> headers, List<int>? body);

Future<Answer> httpSend(
    String method, Uri url, Map<String, String> headers, List<int>? body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.openUrl(method, url);
    headers.forEach(req.headers.set);
    if (body != null) req.add(body);
    final res = await req.close().timeout(const Duration(seconds: 60));
    final out = <String, String>{};
    res.headers.forEach((k, v) => out[k.toLowerCase()] = v.join(','));
    return (
      status: res.statusCode,
      headers: out,
      body: await utf8.decodeStream(res).timeout(const Duration(seconds: 60)),
    );
  } finally {
    client.close(force: true);
  }
}

/// LinkedIn's monthly API version. Each is supported for at least a year.
const linkedInVersion = '202610';

/// Demo seeds carry these ids (`post-3`, `draft-1`, `history-12`, and their
/// repeats). Composer posts start `composer_`, so sample content can't go out.
final _sampleId = RegExp(r'^(post-\d{1,3}|draft-\d+|history-\d+)(-\d+)?$');

const _names = {'linkedin': 'LinkedIn'};

/// Sends posts through official APIs. Everything that could stop a send is
/// checked before anything leaves, so a post never half goes out.
class Publisher {
  final Accounts accounts;
  final Directory uploads;
  final Send send;
  Publisher(this.accounts, this.uploads, {Send? send}) : send = send ?? httpSend;

  Future<Map<String, dynamic>> call(Map<String, dynamic> post) async {
    if (_sampleId.hasMatch('${post['id']}')) {
      throw StateError('This is a sample post, so it was not sent.');
    }
    final platforms = List<String>.from(post['platforms'] as List? ?? const []);
    if (platforms.isEmpty) throw StateError('No channel is selected.');
    final unsupported = platforms.where((p) => !_names.containsKey(p)).toList();
    if (unsupported.isNotEmpty) {
      throw StateError(
          'Lema cannot publish to ${unsupported.join(', ')} yet. Remove it and send again. Nothing was sent.');
    }
    // shortcut: one platform per post until a second adapter exists; P5 must
    // record a result per platform before this can loop.
    final status = accounts.statuses()['linkedin'];
    if (status == null) throw StateError('LinkedIn is not connected. Nothing was sent.');
    final token = await accounts.accessToken('linkedin');
    if (status == 'expired' || token == null) {
      throw StateError('The LinkedIn connection expired. Reconnect in Settings. Nothing was sent.');
    }
    return _linkedIn(post, token);
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Linkedin-Version': linkedInVersion,
        'X-Restli-Protocol-Version': '2.0.0',
        'Content-Type': 'application/json',
      };

  Never _refused(String step, Answer a) {
    if (a.status == 401) accounts.markExpired('linkedin');
    String detail = '';
    try {
      detail = ': ${(jsonDecode(a.body) as Map)['message']}';
    } catch (_) {}
    throw StateError('LinkedIn refused the $step (HTTP ${a.status}$detail).');
  }

  Future<Map<String, dynamic>> _linkedIn(Map<String, dynamic> post, String token) async {
    final caption = '${post['caption'] ?? ''}'.trim();
    if (caption.isEmpty) throw StateError('LinkedIn needs a caption. Nothing was sent.');
    final file = _mediaFile(post);
    if (post['mediaType'] == 'video' && file != null) {
      throw StateError('Video to LinkedIn is not built yet. Nothing was sent.');
    }

    final me = await send('GET', Uri.parse('https://api.linkedin.com/v2/userinfo'),
        {'Authorization': 'Bearer $token'}, null);
    if (me.status != 200) _refused('account check', me);
    final author = 'urn:li:person:${(jsonDecode(me.body) as Map)['sub']}';

    final body = <String, dynamic>{
      'author': author,
      'commentary': escapeLittle(caption),
      'visibility': 'PUBLIC',
      'distribution': {
        'feedDistribution': 'MAIN_FEED',
        'targetEntities': [],
        'thirdPartyDistributionChannels': [],
      },
      'lifecycleState': 'PUBLISHED',
      'isReshareDisabledByAuthor': false,
    };
    if (file != null) {
      body['content'] = {
        'media': {'id': await _uploadImage(file, author, token)}
      };
    }

    // From here the post may reach LinkedIn, so anything unclear is unknown,
    // never failed: a failed post can be retried and would then appear twice.
    final Answer made;
    try {
      made = await send('POST', Uri.parse('https://api.linkedin.com/rest/posts'),
          _headers(token), utf8.encode(jsonEncode(body)));
    } catch (_) {
      throw ResultUnknown('The connection to LinkedIn broke during the send, so it may have gone out. Check LinkedIn.');
    }
    if (made.status >= 500) {
      throw ResultUnknown('LinkedIn had an error during the send (HTTP ${made.status}).');
    }
    if (made.status != 201) _refused('post', made);
    final id = made.headers['x-restli-id'];
    return {
      'platformPostId': id,
      if (id != null) 'postUrl': 'https://www.linkedin.com/feed/update/$id/',
    };
  }

  /// The post's own image, or null for text. A post that names media it can't
  /// find fails, rather than going out without its picture.
  File? _mediaFile(Map<String, dynamic> post) {
    final local = post['localFilePath'] as String?;
    final url = '${post['mediaUrl'] ?? ''}';
    if ((local == null || local.isEmpty) && url.isEmpty) return null;
    final name = Uri.tryParse(url)?.path.split('/uploads/');
    final file = local != null && local.isNotEmpty
        ? File(local)
        : name != null && name.length == 2
            ? File('${uploads.path}/${name[1].split('/').last}')
            : null;
    if (file == null || !file.existsSync()) {
      throw StateError('Cannot find this post\'s media file. Nothing was sent.');
    }
    return file;
  }

  Future<String> _uploadImage(File file, String owner, String token) async {
    final start = await send(
        'POST',
        Uri.parse('https://api.linkedin.com/rest/images?action=initializeUpload'),
        _headers(token),
        utf8.encode(jsonEncode({
          'initializeUploadRequest': {'owner': owner}
        })));
    if (start.status != 200) _refused('image upload', start);
    final value = (jsonDecode(start.body) as Map)['value'] as Map;
    final put = await send('PUT', Uri.parse('${value['uploadUrl']}'),
        {'Authorization': 'Bearer $token'}, await file.readAsBytes());
    if (put.status >= 300) _refused('image upload', put);
    return '${value['image']}';
  }
}

/// LinkedIn cuts a post at an unescaped reserved character. `#` stays so
/// hashtags work.
String escapeLittle(String text) =>
    text.replaceAllMapped(RegExp(r'[\\|{}@\[\]()<>*_~]'), (m) => '\\${m[0]}');
