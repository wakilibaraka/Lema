import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/posts_provider.dart';
import '../services/analytics_service.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  AnalyticsResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final posts = context.read<PostsProvider>().publishedPosts;
    final result = await AnalyticsService.instance.fetchAggregatedAnalytics(posts);
    if (mounted) {
      setState(() {
        _result = result;
        _loading = false;
      });
    }
  }

  /// The fetch is per-post over a snapshot of the published set, so a post
  /// published (or removed) after that snapshot would otherwise keep its
  /// stale, missing, or mismatched row until a manual Refresh.
  void _reloadIfPublishedSetChanged(int publishedCount) {
    if (_loading || _result == null) return;
    if (_result!.perPost.length == publishedCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsProvider = context.watch<PostsProvider>();
    final publishedPosts = postsProvider.publishedPosts;
    _reloadIfPublishedSetChanged(publishedPosts.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post Analytics',
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
                        'Track likes, views, comments, and shares per post.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: AppleTheme.systemBlue,
                  // Plain CupertinoButton defaults its foreground to the
                  // same #007AFF as this background; set it explicitly.
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  onPressed: _loadAnalytics,
                  child: const Text(
                    'Refresh',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CupertinoActivityIndicator())
            else if (_result == null || publishedPosts.isEmpty)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.chart_bar, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      'No published posts to analyze',
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryCards(isDark),
                      const SizedBox(height: 16),
                      // Pair by post id: an index pair reattached one
                      // post's metrics to whichever post shifted into its
                      // slot when the published set changed.
                      ...publishedPosts.map((post) {
                        final analytics = _result!.forPost(post.id) ??
                            PostAnalytics(
                              postId: post.id,
                              platform: post.primaryPlatform.name,
                            );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildPostAnalyticsCard(post, analytics, isDark),
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    return Row(
      children: [
        _buildSummaryCard('Likes', _result!.totalLikes, AppleTheme.systemPink, CupertinoIcons.heart_fill, isDark),
        const SizedBox(width: 12),
        _buildSummaryCard('Views', _result!.totalViews, AppleTheme.systemBlue, CupertinoIcons.eye_fill, isDark),
        const SizedBox(width: 12),
        _buildSummaryCard('Comments', _result!.totalComments, AppleTheme.systemGreen, CupertinoIcons.chat_bubble_2_fill, isDark),
        const SizedBox(width: 12),
        _buildSummaryCard('Shares', _result!.totalShares, AppleTheme.systemPurple, CupertinoIcons.arrow_2_squarepath, isDark),
      ],
    );
  }

  Widget _buildSummaryCard(String label, int value, Color color, IconData icon, bool isDark) {
    return Expanded(
      child: AppleGlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              _formatCount(value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostAnalyticsCard(PostModel post, PostAnalytics analytics, bool isDark) {
    return AppleGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: post.platformInfo.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  post.platformInfo.name,
                  style: TextStyle(
                    color: post.platformInfo.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetric('Likes', analytics.likes, isDark),
              _buildMetric('Views', analytics.views, isDark),
              _buildMetric('Comments', analytics.comments, isDark),
              _buildMetric('Shares', analytics.shares, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, int value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            _formatCount(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.black54),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
