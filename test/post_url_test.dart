import 'package:flutter_test/flutter_test.dart';
import 'package:lema/core/models/post_model.dart';

void main() {
  test('the published link survives a save and reload', () {
    final post = PostModel.fromJson({'id': 'a', 'postUrl': 'https://l/1'});
    expect(PostModel.fromJson(post.toJson()).postUrl, 'https://l/1');
    expect(post.copyWith(title: 'x').postUrl, 'https://l/1');
  });
}
