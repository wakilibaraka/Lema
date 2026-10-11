import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lema/providers/app_provider.dart';
import 'package:lema/services/storage_service.dart';
import 'package:lema/models/simulation_model.dart';
import 'package:lema/models/post_model.dart';
import 'package:lema/models/platform_info.dart';

class SimulationView extends StatelessWidget {
  const SimulationView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = app.isDarkMode;

    // Load or create a SimulationRun
    SimulationRun run = StorageService.instance.loadSimulationRun() ??
        SimulationRun(
          posts: _seedPosts(),
          platformAssignments: {
            for (var p in _seedPosts()) p: PlatformName.instagram,
          },
          config: const ScoringConfig(),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Simulation')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'View mode',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ViewToggleButton(
                  label: 'Grid',
                  isSelected: app.simulationView == SimulationViewMode.grid,
                  onTap: () => app.setSimulationView(SimulationViewMode.grid),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _ViewToggleButton(
                  label: 'List',
                  isSelected: app.simulationView == SimulationViewMode.list,
                  onTap: () => app.setSimulationView(SimulationViewMode.list),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                // Re‑run scoring with current config.
                final config = run.config.copyWith(
                  engagementWeight: 1.0,
                  timeDecayFactor: 0.1,
                );
                final newResults = run.platformAssignments.entries.map((entry) {
                  final post = entry.key;
                  final platform = entry.value;
                  final score = defaultScoreFunction(post, platform, config);
                  return ScoreResult(
                    totalScore: score,
                    engagementComponent: score * 0.6,
                    decayComponent: score * 0.4,
                    platformBonuses: {platform: config.platformBonus[platform] ?? 0.0},
                  );
                }).toList();

                final updatedRun = run.copyWith(results: newResults);
                StorageService.instance.saveSimulationRun(updatedRun);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Simulation scored & saved')),
                );
              },
              child: const Text('Score Simulation'),
            ),
            const SizedBox(height: 12),

            Text(
              'Run ID: ${run.id.substring(0, 8)}',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Posts simulated: ${run.posts.length}',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey),
            ),
            const SizedBox(height: 24),

            const Text(
              'Simulated Feed',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _BuildFeed(
                viewMode: app.simulationView,
                posts: run.posts,
                platformAssignments: run.platformAssignments,
                config: run.config,
              ),
            ),
          ],
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

  // _persistRun removed – persistence is handled via StorageService directly.

  // Helper functions used inside the widget -------------------------------------------------

  // defaultScoreFunction is defined in simulation_model.dart; we reference it via the typedef.
  // No extra code needed here.
}

// -----------------------------------------------------------------------------
// View‑mode toggle button
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
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.white24 : Colors.grey.shade300);
    final textColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white70 : Colors.black87);

    return Expanded(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white30 : Colors.black26),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Feed builder – grid or list
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
    Key? key,
  }) : super(key: key);

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

  const _FeedCard({
    required this.post,
    required this.platform,
    required this.aspectRatio,
    required this.isGrid,
    Key? key,
  }) : super(key: key);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media placeholder respecting aspect ratio
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              color: color.withAlpha(30),
              child: const Icon(Icons.image, size: 80, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              post.caption ?? '',
              maxLines: isGrid ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${post.likes.toString().padLeft(3) ?? '0'} likes',
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}