import 'dart:convert';
import 'package:lema/lib/models/post_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlatformName { instagram, tiktok, youtube, twitter, facebook }

extension PlatformNameAspectRatio on PlatformName {
  double get aspectRatio {
    switch (this) {
      case PlatformName.instagram:
        return 1.0;
      case PlatformName.tiktok:
        return 9.0 / 16.0;
      case PlatformName.youtube:
        return 9.0 / 16.0;
      case PlatformName.twitter:
        return 16.0 / 9.0;
      case PlatformName.facebook:
        return 1.0;
    }
  }
}

enum SimulationViewMode { grid, list }

class ScoringConfig {
  final double engagementWeight;
  final double timeDecayFactor;
  final Map<PlatformName, double> platformBonus;

  const ScoringConfig({
    this.engagementWeight = 1.0,
    this.timeDecayFactor = 0.1,
    this.platformBonus = const {},
  });

  ScoringConfig copyWith({
    double? engagementWeight,
    double? timeDecayFactor,
    Map<PlatformName, double>? platformBonus,
  }) {
    return ScoringConfig(
      engagementWeight: engagementWeight ?? this.engagementWeight,
      timeDecayFactor: timeDecayFactor ?? this.timeDecayFactor,
      platformBonus: platformBonus ?? this.platformBonus,
    );
  }
}

class ScoreResult {
  final double totalScore;
  final double engagementComponent;
  final double decayComponent;
  final Map<PlatformName, double> platformBonuses;

  ScoreResult({
    required this.totalScore,
    required this.engagementComponent,
    required this.decayComponent,
    required this.platformBonuses,
  });

  Map<String, dynamic> toJson() => {
        'totalScore': totalScore,
        'engagementComponent': engagementComponent,
        'decayComponent': decayComponent,
        'platformBonuses': platformBonuses.entries.map((e) => [e.key.toString(), e.value]).toMap(),
      };

  static ScoreResult fromJson(Map<String, dynamic> json) => ScoreResult(
        totalScore: json['totalScore'] as double,
        engagementComponent: json['engagementComponent'] as double,
        decayComponent: json['decayComponent'] as double,
        platformBonuses: (json['platformBonuses'] as Map<String, dynamic>).map((k, v) => MapEntry(PlatformName.values.firstWhere((e) => e.toString() == k, orElse: () => PlatformName.instagram), v as double)),
      );
}

class SimulationRun {
  final String id;
  final DateTime createdAt;
  final List<PostModel> posts;
  final Map<PostModel, PlatformName> platformAssignments;
  final ScoringConfig config;
  final List<ScoreResult> results;

  SimulationRun({
    String? id,
    DateTime? createdAt,
    required this.posts,
    required this.platformAssignments,
    required this.config,
    List<ScoreResult>? results,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now(),
        results = results ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'posts': posts.map((p) => p.toMap()).toList(),
        'platformAssignments':
            platformAssignments.entries.map((e) => {'postId': e.key.id, 'platform': e.value.toString()}).toList(),
        'config': {
          'engagementWeight': config.engagementWeight,
          'timeDecayFactor': config.timeDecayFactor,
          'platformBonus': config.platformBonuses.map((k, v) => [k.toString(), v]),
        },
        'results': results.map((r) => r.toJson()).toList(),
      };

  factory SimulationRun.fromJson(Map<String, dynamic> json) {
    final postsList = (json['posts'] as List).map((m) => PostModel.fromMap(m)).toList();
    final pa = <PostModel, PlatformName>{};
    for (final entry in json['platformAssignments'] as List) {
      final post = postsList.firstWhere((p) => p.id == entry['postId'], orElse: () => postsList.first);
      final plat = PlatformName.values.firstWhere(
        (p) => p.toString() == entry['platform'],
        orElse: () => PlatformName.instagram,
      );
      pa[post] = plat;
    }
    final cfgMap = json['config'] as Map<String, dynamic>;
    final config = ScoringConfig(
      engagementWeight: cfgMap['engagementWeight'] as double? ?? 1.0,
      timeDecayFactor: cfgMap['timeDecayFactor'] as double? ?? 0.1,
      platformBonus: (cfgMap['platformBonus'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(PlatformName.values.firstWhere((e) => e.toString() == k, orElse: () => PlatformName.instagram), v as double)),
    );
    final resultsList = (json['results'] as List?)
        ?.map((r) => ScoreResult.fromJson(r as Map<String, dynamic>))
        .toList() ?? [];
    return SimulationRun(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      posts: postsList,
      platformAssignments: pa,
      config: config,
      results: resultsList,
    );
  }

  SimulationRun copyWith({
    String? id,
    DateTime? createdAt,
    List<PostModel>? posts,
    Map<PostModel, PlatformName>? platformAssignments,
    ScoringConfig? config,
    List<ScoreResult>? results,
  }) {
    return SimulationRun(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      posts: posts ?? this.posts,
      platformAssignments: platformAssignments ?? this.platformAssignments,
      config: config ?? this.config,
      results: results ?? this.results,
    );
  }
}

typedef ScorePostFunction(PostModel post, PlatformName platform, ScoringConfig config) => double;

final ScorePostFunction defaultScoreFunction = (PostModel post, PlatformName platform, ScoringConfig config) {
  final likes = double.tryParse(post.likes ?? '0') ?? 0.0;
  final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
  final postTime = post.createdAt?.millisecondsSinceEpoch / 1000.0 ?? now;
  final timeDecay = (now - postTime) * config.timeDecayFactor;
  final platformBonus = config.platformBonus[platform] ?? 0.0;
  return (likes * config.engagementWeight - timeDecay + platformBonus).clamp(0, double.infinity);
};