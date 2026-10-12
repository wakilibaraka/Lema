import 'package:lema/models/post_model.dart';

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

/// Reversible platform-name codec so JSON round-trips survive an enum rename.
PlatformName _platformFromKey(String key, PlatformName fallback) {
  for (final p in PlatformName.values) {
    if (p.toString() == key || p.name == key) return p;
  }
  return fallback;
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
        'platformBonuses':
            platformBonuses.map((k, v) => MapEntry(k.toString(), v)),
      };

  static ScoreResult fromJson(Map<String, dynamic> json) {
    final rawBonuses = json['platformBonuses'];
    return ScoreResult(
      totalScore: (json['totalScore'] as num? ?? 0).toDouble(),
      engagementComponent: (json['engagementComponent'] as num? ?? 0).toDouble(),
      decayComponent: (json['decayComponent'] as num? ?? 0).toDouble(),
      platformBonuses: rawBonuses is Map
          ? rawBonuses.map(
              (k, v) => MapEntry(
                _platformFromKey(k.toString(), PlatformName.instagram),
                (v as num).toDouble(),
              ),
            )
          : <PlatformName, double>{},
    );
  }
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
        'posts': posts.map((p) => p.toJson()).toList(),
        'platformAssignments': platformAssignments.entries
            .map((e) => {'postId': e.key.id, 'platform': e.value.toString()})
            .toList(),
        'config': {
          'engagementWeight': config.engagementWeight,
          'timeDecayFactor': config.timeDecayFactor,
          'platformBonus':
              config.platformBonus.map((k, v) => MapEntry(k.toString(), v)),
        },
        'results': results.map((r) => r.toJson()).toList(),
      };

  factory SimulationRun.fromJson(Map<String, dynamic> json) {
    final postsList = (json['posts'] as List? ?? [])
        .whereType<Map>()
        .map((m) => PostModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    final pa = <PostModel, PlatformName>{};
    for (final entry in (json['platformAssignments'] as List? ?? [])) {
      if (entry is! Map || postsList.isEmpty) continue;
      final id = entry['postId'];
      final idx = postsList.indexWhere((p) => p.id == id);
      if (idx == -1) continue;
      pa[postsList[idx]] = _platformFromKey(
        entry['platform']?.toString() ?? '',
        PlatformName.instagram,
      );
    }

    final cfgMap = Map<String, dynamic>.from(
      (json['config'] as Map?) ?? const {},
    );
    final rawBonus = cfgMap['platformBonus'];
    final config = ScoringConfig(
      engagementWeight: (cfgMap['engagementWeight'] as num? ?? 1.0).toDouble(),
      timeDecayFactor: (cfgMap['timeDecayFactor'] as num? ?? 0.1).toDouble(),
      platformBonus: rawBonus is Map
          ? rawBonus.map(
              (k, v) => MapEntry(
                _platformFromKey(k.toString(), PlatformName.instagram),
                (v as num).toDouble(),
              ),
            )
          : <PlatformName, double>{},
    );

    return SimulationRun(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      posts: postsList,
      platformAssignments: pa,
      config: config,
      results: (json['results'] as List? ?? [])
          .whereType<Map>()
          .map((r) => ScoreResult.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
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

double defaultScoreFunction(
    PostModel post, PlatformName platform, ScoringConfig config) {
  final likes = double.tryParse(post.likes) ?? 0.0;
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final postMs = post.createdAt?.millisecondsSinceEpoch ?? nowMs;
  final timeDecay = ((nowMs - postMs) / 1000.0) * config.timeDecayFactor;
  final platformBonus = config.platformBonus[platform] ?? 0.0;
  return (likes * config.engagementWeight - timeDecay + platformBonus)
      .clamp(0, double.infinity);
}
