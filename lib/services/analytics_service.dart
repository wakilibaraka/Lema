import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/post_model.dart';

class PostAnalytics {
  final String postId;
  final String platform;
  final int likes;
  final int views;
  final int comments;
  final int shares;
  final DateTime fetchedAt;

  PostAnalytics({
    required this.postId,
    required this.platform,
    this.likes = 0,
    this.views = 0,
    this.comments = 0,
    this.shares = 0,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'postId': postId,
        'platform': platform,
        'likes': likes,
        'views': views,
        'comments': comments,
        'shares': shares,
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory PostAnalytics.fromJson(Map<String, dynamic> json) => PostAnalytics(
        postId: json['postId'] as String,
        platform: json['platform'] as String,
        likes: json['likes'] as int? ?? 0,
        views: json['views'] as int? ?? 0,
        comments: json['comments'] as int? ?? 0,
        shares: json['shares'] as int? ?? 0,
        fetchedAt: json['fetchedAt'] != null
            ? DateTime.tryParse(json['fetchedAt'] as String)
            : null,
      );
}

class AnalyticsResult {
  final List<PostAnalytics> perPost;
  final int totalLikes;
  final int totalViews;
  final int totalComments;
  final int totalShares;
  final int totalEngagement;
  final double engagementRate;

  AnalyticsResult({
    required this.perPost,
    this.totalLikes = 0,
    this.totalViews = 0,
    this.totalComments = 0,
    this.totalShares = 0,
  })  : totalEngagement = totalLikes + totalComments + totalShares,
        engagementRate = totalViews > 0
            ? ((totalLikes + totalComments + totalShares) / totalViews) * 100
            : 0;
}

class AnalyticsService {
  final String baseUrl;
  static AnalyticsService? _instance;

  const AnalyticsService({this.baseUrl = 'http://localhost:3001'});

  static AnalyticsService get instance => _instance ??= const AnalyticsService();

  Future<PostAnalytics> fetchPostAnalytics(PostModel post) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/analytics/${post.id}'))
              .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return PostAnalytics.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    return PostAnalytics(
      postId: post.id,
      platform: post.primaryPlatform.name,
      likes: post.likesCount,
      views: int.tryParse(post.views.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      comments: post.comments,
    );
  }

  Future<AnalyticsResult> fetchAggregatedAnalytics(List<PostModel> posts) async {
    final List<PostAnalytics> perPost = [];
    int totalLikes = 0;
    int totalViews = 0;
    int totalComments = 0;
    int totalShares = 0;

    for (final post in posts) {
      final analytics = await fetchPostAnalytics(post);
      perPost.add(analytics);
      totalLikes += analytics.likes;
      totalViews += analytics.views;
      totalComments += analytics.comments;
      totalShares += analytics.shares;
    }

    return AnalyticsResult(
      perPost: perPost,
      totalLikes: totalLikes,
      totalViews: totalViews,
      totalComments: totalComments,
      totalShares: totalShares,
    );
  }

  static Map<String, int> getEmptyAnalytics() => {
        'likes': 0,
        'views': 0,
        'comments': 0,
        'shares': 0,
      };
}
