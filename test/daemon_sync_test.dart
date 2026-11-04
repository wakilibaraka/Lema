import 'package:flutter_test/flutter_test.dart';
import 'package:lema/core/models/post_model.dart';
import 'package:lema/core/providers/posts_provider.dart';
import 'package:lema/core/services/api_service.dart';
import 'package:lema/core/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends ApiService {
  List<Map<String, dynamic>>? answer;
  @override
  Future<List<Map<String, dynamic>>?> syncPosts(List<PostModel> posts) async => answer;
}

void main() {
  late _Api api;
  late PostsProvider provider;
  final at = DateTime(2030, 1, 1, 9);
  PostModel post(String id, String status) => PostModel(
      id: id, caption: id, mediaUrl: '', status: status, scheduledTime: at);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    final storage = StorageService(await SharedPreferences.getInstance());
    provider = PostsProvider(storage, api);
    provider.addPost(post('mine', 'scheduled'));
    provider.addPost(post('draft', 'draft'));
    await Future<void>.delayed(Duration.zero); // Let the add's own sync finish.
  });

  PostModel byId(String id) => provider.posts.firstWhere((p) => p.id == id);

  test('no daemon leaves every local post alone', () async {
    final before = provider.posts.length;
    await provider.syncWithBackend();
    expect(provider.posts.length, before);
  });

  test('a daemon result replaces a scheduled post only', () async {
    api.answer = [
      post('mine', 'published').toJson(),
      post('draft', 'failed').toJson(),
    ];
    await provider.syncWithBackend();
    expect(byId('mine').status, 'published');
    expect(byId('draft').status, 'draft');
  });

  test('only repeats the daemon queued are added', () async {
    api.answer = [
      {...post('next', 'scheduled').toJson(), 'createdByDaemon': true},
      post('deleted-here', 'published').toJson(),
    ];
    await provider.syncWithBackend();
    expect(byId('next').status, 'scheduled');
    expect(provider.posts.any((p) => p.id == 'deleted-here'), isFalse);
  });
}
