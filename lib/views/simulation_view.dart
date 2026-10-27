import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lema/providers/app_provider.dart';
import 'package:lema/services/storage_service.dart';
import 'package:lema/models/simulation_model.dart';
import 'package:lema/models/post_model.dart';
import 'package:lema/models/platform_info.dart';
import 'package:lema/theme/backdrop_theme.dart';

/// Slice 25 — offline-first simulation engine.
///
/// Scores a deterministic set of posts against per-platform bonuses and
/// persists the run so it survives a restart. Everything runs on-device:
/// no daemon, no network. The shell (`MainLayoutScreen`) owns the app bar
/// and the docked tab bar, so this view renders a plain scrollable body.
class SimulationView extends StatefulWidget {
  const SimulationView({super.key});

  @override
  State<SimulationView> createState() => _SimulationViewState();
}

class _SimulationViewState extends State<SimulationView> {
  late SimulationRun _run;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    // Seed once so `posts` and `platformAssignments` share identical
    // instances — PostModel uses identity equality, so two separate
    // _seedPosts() calls would leave every assignment lookup null.
    _run = StorageService.instance.loadSimulationRun() ?? _freshRun();
  }

  SimulationRun _freshRun() {
    final seeds = _seedPosts();
    return SimulationRun(
      posts: seeds,
      platformAssignments: {
        for (final p in seeds) p: PlatformName.instagram,
      },
      config: const ScoringConfig(),
    );
  }

  Future<void> _score() async {
    final config = _run.config.copyWith(
      engagementWeight: 1.0,
      timeDecayFactor: 0.1,
    );
    final results = _run.platformAssignments.entries.map((entry) {
      final score = defaultScoreFunction(entry.key, entry.value, config);
      return ScoreResult(
        totalScore: score,
        engagementComponent: score * 0.6,
        decayComponent: score * 0.4,
        platformBonuses: {entry.value: config.platformBonus[entry.value] ?? 0.0},
      );
    }).toList();

    setState(() => _run = _run.copyWith(results: results));
    await StorageService.instance.saveSimulationRun(_run);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Simulation scored & saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mode = app.simulationView;

    return Padding(
      // Bottom clearance for the docked glass tab bar (extendBody: true).
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Simulation',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Offline scoring across platforms. No daemon, no network.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                'View mode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 12),
              _ViewToggleButton(
                label: 'Grid',
                isSelected: mode == SimulationViewMode.grid,
                onTap: () =>
                    app.setSimulationView(SimulationViewMode.grid),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _ViewToggleButton(
                label: 'List',
                isSelected: mode == SimulationViewMode.list,
                onTap: () => app.setSimulationView(SimulationViewMode.list),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(vertical: 13),
            borderRadius: BorderRadius.circular(12),
            onPressed: _score,
            child: const Text(
              'Score Simulation',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _metaChip('Run', _shortId(_run.id), isDark),
              _metaChip('Posts', '${_run.posts.length}', isDark),
              _metaChip('Scored', '${_run.results.length}', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'SIMULATED FEED',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _BuildFeed(
              viewMode: mode,
              posts: _run.posts,
              platformAssignments: _run.platformAssignments,
              config: _run.config,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortId(String id) =>
      id.length <= 8 ? id : id.substring(0, 8);

  Widget _metaChip(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label · $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  static List<PostModel> _seedPosts() {
    return [
      PostModel(
        id: 'p1',
        mediaUrl: 'https://picsum.photos/seed/1/400/600',
        caption: 'First post',
        likes: '124',
        platform: SocialPlatform.instagram,
        platforms: ['instagram'],
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      PostModel(
        id: 'p2',
        mediaUrl: 'https://picsum.photos/seed/2/400/600',
        caption: 'Second post',
        likes: '98',
        platform: SocialPlatform.tiktok,
        platforms: ['tiktok'],
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      PostModel(
        id: 'p3',
        mediaUrl: 'https://picsum.photos/seed/3/400/600',
        caption: 'Third post',
        likes: '210',
        platform: SocialPlatform.youtube,
        platforms: ['youtube'],
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }
}

// -----------------------------------------------------------------------------
// View-mode toggle button
// -----------------------------------------------------------------------------
class _ViewToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _ViewToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final selected = isSelected;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      minimumSize: const Size(0, 32),
      color: selected
          ? BackdropTheme.accent
          : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(8)),
      borderRadius: BorderRadius.circular(16),
      foregroundColor: selected
          ? Colors.white
          : (isDark ? Colors.white70 : Colors.black87),
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Feed builder — grid or list
// -----------------------------------------------------------------------------
class _BuildFeed extends StatelessWidget {
  final SimulationViewMode viewMode;
  final List<PostModel> posts;
  final Map<PostModel, PlatformName> platformAssignments;
  final ScoringConfig config;

  const _BuildFeed({
    required this.viewMode,
    required this.posts,
    required this.platformAssignments,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final isGrid = viewMode == SimulationViewMode.grid;
    final crossAxisCount = isGrid ? 2 : 1;
    final aspectRatio = isGrid ? 4.0 / 5.0 : 1.0;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: aspectRatio,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final platform = platformAssignments[post] ?? PlatformName.instagram;
        return _FeedCard(
          post: post,
          platform: platform,
          aspectRatio: platform.aspectRatio,
          isGrid: isGrid,
          score: defaultScoreFunction(post, platform, config),
        );
      },
    );
  }
}

class _FeedCard extends StatelessWidget {
  final PostModel post;
  final PlatformName platform;
  final double aspectRatio;
  final bool isGrid;
  final double score;

  const _FeedCard({
    required this.post,
    required this.platform,
    required this.aspectRatio,
    required this.isGrid,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final color = platform == PlatformName.instagram
        ? const Color(0xFFE1306C)
        : platform == PlatformName.tiktok
            ? const Color(0xFFFE2C55)
            : platform == PlatformName.youtube
                ? Colors.red
                : platform == PlatformName.twitter
                    ? Colors.black
                    : Colors.blue;

    return Card(
      color: const Color(0xFF1E1E1E),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media placeholder respecting aspect ratio
          Expanded(
            child: Container(
              width: double.infinity,
              color: color.withAlpha(30),
              child: const Icon(Icons.image, size: 48, color: Colors.white24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(
              post.caption,
              maxLines: isGrid ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${post.likes.padLeft(3)} likes',
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
                Text(
                  score.toStringAsFixed(1),
                  style: const TextStyle(
                    color: BackdropTheme.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
