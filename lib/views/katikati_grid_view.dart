import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/posts_provider.dart';
import '../theme/apple_theme.dart';
import '../widgets/media_player_widget.dart';

/// Katikati Grid — visually-driven drag-and-drop feed planner.
///
/// Design language lifted directly from the travel reference screenshots:
///  * extreme border radii (24–32), soft drop shadows, frosted glassmorphism
///  * high-contrast off-white canvas (#F5F5F8) + black / dark-gray type
///  * immersive edge-to-edge hero preview card (Norway Fjord Escape pattern)
///  * floating segmented filter pills (trip-length / climate pattern)
///  * vertical accordion day timeline (Day 1 Arrival pattern)
///  * floating bottom-sheet quick-edit modal (trip-suggestion sheet pattern)
class KatikatiGridView extends StatefulWidget {
  const KatikatiGridView({super.key});

  @override
  State<KatikatiGridView> createState() => _KatikatiGridViewState();
}

class _KatikatiGridViewState extends State<KatikatiGridView> {
  String _platformFilter = 'all'; // all | instagram | tiktok | youtube | facebook
  String _statusFilter = 'all'; // all | scheduled | draft | published
  String _formatFilter = 'all'; // all | video | image
  int _heroIndex = 0;
  final Set<String> _expandedDays = {};
  String? _draggingId;

  static const _lime = Color(0xFFD3E157);

  List<PostModel> _filtered(List<PostModel> all) {
    return all.where((p) {
      final platformOk = _platformFilter == 'all' ||
          p.platforms.contains(_platformFilter) ||
          p.primaryPlatform.name == _platformFilter;
      final statusOk =
          _statusFilter == 'all' || p.status.toLowerCase() == _statusFilter;
      final formatOk = _formatFilter == 'all' ||
          (_formatFilter == 'video' ? p.isVideo : !p.isVideo);
      return platformOk && statusOk && formatOk;
    }).toList();
  }

  int _hashtagCount(String caption) =>
      RegExp(r'#\w+').allMatches(caption).length;

  Map<String, List<PostModel>> _groupByDay(List<PostModel> posts) {
    final map = <String, List<PostModel>>{};
    for (final p in posts) {
      final key = DateFormat('yyyy-MM-dd').format(p.scheduledTime);
      map.putIfAbsent(key, () => []).add(p);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {for (final k in sortedKeys) k: map[k]!};
  }

  void _openQuickEdit(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickEditSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsProvider = context.watch<PostsProvider>();
    final all = postsProvider.posts;
    final filtered = _filtered(all);
    final scheduled = all.where((p) => p.status == 'scheduled').length;
    final drafts = all.where((p) => p.status == 'draft').length;
    final heroPost =
        filtered.isEmpty ? null : filtered[_heroIndex % filtered.length];

    // Off-white canvas on light mode keeps the travel-ref contrast.
    final canvas = isDark ? null : const Color(0xFFF5F5F8);

    return Scaffold(
      backgroundColor: canvas ?? Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(isDark, scheduled, drafts)),
          SliverToBoxAdapter(
              child: _buildStatsStrip(context, isDark, scheduled, drafts)),
          if (heroPost != null)
            SliverToBoxAdapter(
                child: _buildHeroPreview(context, isDark, heroPost, filtered)),
          SliverToBoxAdapter(child: _buildFilterPills(isDark)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    'FEED GRID · DRAG TO REORDER',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const Spacer(),
                  Icon(CupertinoIcons.move,
                      size: 12,
                      color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Text(
                    '${filtered.length} assets',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDragGrid(isDark, filtered),
          SliverToBoxAdapter(child: _buildTimelineHeader(isDark)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final groups = _groupByDay(filtered);
                final key = groups.keys.elementAt(i);
                return _buildDayAccordion(
                    context, isDark, key, groups[key]!, i);
              },
              childCount: _groupByDay(filtered).keys.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }

  // ── Header: "TRAVELING UP / Where should we take you today?" ──────────
  Widget _buildHeader(bool isDark, int scheduled, int drafts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KATIKATI GRID',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Good morning, Emms',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF3A3A3C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Where should we\npost today?',
            style: TextStyle(
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$scheduled queued posts · $drafts drafts ready. Tap, drag, ship.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ── Overlapping stat pill (6 Saved places / 3 Surprise routes) ────────
  Widget _buildStatsStrip(
      BuildContext context, bool isDark, int scheduled, int drafts) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C22) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withAlpha(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 60 : 14),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$scheduled',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 2),
                    Text('Queued posts',
                        style: TextStyle(
                            fontSize: 11.5,
                            color:
                                isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ),
            ),
            Container(width: 1, height: 44,
                color: isDark ? Colors.white12 : Colors.black12),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$drafts',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 2),
                    Text('Draft ideas',
                        style: TextStyle(
                            fontSize: 11.5,
                            color:
                                isDark ? Colors.white54 : Colors.black54)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => setState(() => _heroIndex++),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(14)
                        : const Color(0xFFE8E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.shuffle, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero immersive preview (Norway Fjord Escape card → Reel card) ─────
  Widget _buildHeroPreview(BuildContext context, bool isDark,
      PostModel post, List<PostModel> pool) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              height: 400,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 80 : 30),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  UniversalMediaPlayer(
                    mediaUrl: post.mediaUrl,
                    isVideo: post.isVideo,
                    fit: BoxFit.cover,
                    autoPlay: true,
                    showControls: false,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha(70),
                          Colors.black.withAlpha(30),
                          Colors.black.withAlpha(120),
                          Colors.black.withAlpha(200),
                        ],
                        stops: const [0.0, 0.32, 0.62, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Top frosted bar: YOUR RANDOM PICK pattern
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(38),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withAlpha(60), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.back,
                          color: Colors.white, size: 16),
                      Expanded(
                        child: Text(
                          'YOUR NEXT POST · ${post.platformInfo.name.toUpperCase()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const Icon(CupertinoIcons.bookmark,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom-anchored stack (Slice 2): title + meta pill + glass sheet.
          // Anchoring the type to the sheet guarantees it never collides
          // with faces mid-frame, whatever the sheet height.
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    post.title.isEmpty ? 'Untitled Reel' : post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.08,
                      shadows: [
                        Shadow(
                            color: Colors.black87,
                            blurRadius: 16,
                            offset: Offset(0, 2))
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${DateFormat('EEE h:mm a').format(post.scheduledTime)} · ${post.isVideo ? 'Reel' : 'Carousel'} · ${_hashtagCount(post.caption)} tags',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withAlpha(150)
                            : Colors.white.withAlpha(225),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withAlpha(30)
                              : Colors.white.withAlpha(200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Row(
                        children: [
                          Text(
                            'WHY THIS POST',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black45,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _heroIndex++),
                            child: Row(
                              children: [
                                Text('Shuffle again',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54)),
                                const SizedBox(width: 4),
                                const Icon(CupertinoIcons.shuffle,
                                    size: 14),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.hook.isEmpty
                            ? 'High-retention opener verified.'
                            : post.hook,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '${post.views} views potential · Low competition · Prime slot',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white60
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  _openQuickEdit(context, post),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Plan this post',
                                      style: TextStyle(
                                        fontWeight:
                                            FontWeight.w700,
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () =>
                                _openQuickEdit(context, post),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _lime,
                                borderRadius:
                                    BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                  CupertinoIcons.arrow_right,
                                  color: Colors.black,
                                  size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Floating filter pills (trip-length / climate pattern) ─────────────
  Widget _buildFilterPills(bool isDark) {
    Widget pill(String label, bool selected, VoidCallback onTap,
        {Color? dot}) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : (isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(10)),
            ),
            boxShadow: [
              if (!selected)
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 8),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              pill('All', _platformFilter == 'all',
                  () => setState(() => _platformFilter = 'all')),
              const SizedBox(width: 8),
              pill('Instagram', _platformFilter == 'instagram',
                  () => setState(() => _platformFilter = 'instagram'),
                  dot: const Color(0xFFF56040)),
              const SizedBox(width: 8),
              pill('TikTok', _platformFilter == 'tiktok',
                  () => setState(() => _platformFilter = 'tiktok'),
                  dot: const Color(0xFFFE2C55)),
              const SizedBox(width: 8),
              pill('Shorts', _platformFilter == 'youtube',
                  () => setState(() => _platformFilter = 'youtube'),
                  dot: Colors.red),
              const SizedBox(width: 8),
              pill('Facebook', _platformFilter == 'facebook',
                  () => setState(() => _platformFilter = 'facebook'),
                  dot: const Color(0xFF1877F2)),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              pill('All statuses', _statusFilter == 'all',
                  () => setState(() => _statusFilter = 'all')),
              const SizedBox(width: 8),
              pill('Scheduled', _statusFilter == 'scheduled',
                  () => setState(() => _statusFilter = 'scheduled')),
              const SizedBox(width: 8),
              pill('Drafts', _statusFilter == 'draft',
                  () => setState(() => _statusFilter = 'draft')),
              const SizedBox(width: 8),
              pill('Published', _statusFilter == 'published',
                  () => setState(() => _statusFilter = 'published')),
              const SizedBox(width: 8),
              pill('Video only', _formatFilter == 'video',
                  () => setState(() => _formatFilter = _formatFilter == 'video' ? 'all' : 'video')),
              const SizedBox(width: 8),
              pill('Images', _formatFilter == 'image',
                  () => setState(() => _formatFilter = _formatFilter == 'image' ? 'all' : 'image')),
            ],
          ),
        ),
      ],
    );
  }

  // ── Drag-and-drop 3-col grid (Instagram feed planner) ─────────────────
  Widget _buildDragGrid(bool isDark, List<PostModel> posts) {
    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(CupertinoIcons.square_grid_2x2,
                  size: 40,
                  color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 10),
              Text('No assets match these filters.',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45)),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      sliver: SliverGrid(
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, index) {
            final post = posts[index];
            return DragTarget<int>(
              onAcceptWithDetails: (details) {
                final from = details.data;
                if (from != index) {
                  context
                      .read<PostsProvider>()
                      .reorderPosts(from, index, _platformFilter,
                          _statusFilter, _formatFilter);
                }
                setState(() => _draggingId = null);
              },
              onLeave: (_) => setState(() => _draggingId = null),
              builder: (c, candidate, rejected) {
                final isTarget = candidate.isNotEmpty;
                return LongPressDraggable<int>(
                  data: index,
                  delay: const Duration(milliseconds: 180),
                  feedback: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: 120, maxHeight: 150),
                      child: _gridTile(isDark, post, true, false),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _gridTile(isDark, post, false, false),
                  ),
                  onDragStarted: () =>
                      setState(() => _draggingId = post.id),
                  onDragEnd: (_) =>
                      setState(() => _draggingId = null),
                  child: GestureDetector(
                    onTap: () => _openQuickEdit(context, post),
                    child: _gridTile(
                        isDark, post, false, isTarget),
                  ),
                );
              },
            );
          },
          childCount: posts.length,
        ),
      ),
    );
  }

  Widget _gridTile(
      bool isDark, PostModel post, bool isFeedback, bool isTarget) {
    final tags = _hashtagCount(post.caption);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isTarget
              ? AppleTheme.systemBlue
              : (_draggingId == post.id
                  ? AppleTheme.systemBlue.withAlpha(140)
                  : (isDark
                      ? Colors.white.withAlpha(18)
                      : Colors.black.withAlpha(8))),
          width: isTarget ? 2.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
                isFeedback ? 70 : (isDark ? 50 : 12)),
            blurRadius: isFeedback ? 24 : 14,
            offset: Offset(0, isFeedback ? 12 : 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          fit: StackFit.expand,
          children: [
            UniversalMediaPlayer(
              mediaUrl: post.mediaUrl,
              isVideo: post.isVideo,
              fit: BoxFit.cover,
              autoPlay: false,
              showControls: false,
            ),
            // Top-right frosted bookmark
            Positioned(
              top: 7,
              right: 7,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color:
                          Colors.white.withAlpha(70),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      post.status == 'published'
                          ? CupertinoIcons.checkmark_alt
                          : CupertinoIcons.bookmark,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (post.isVideo)
              const Positioned(
                top: 7,
                left: 7,
                child: Icon(CupertinoIcons.play_circle_fill,
                    color: Colors.white, size: 18),
              ),
            // Bottom frosted meta strip — dense but uncluttered
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withAlpha(120),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: post
                                    .platformInfo.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                DateFormat('h:mm a').format(
                                    post.scheduledTime),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tags > 0 ? '#×$tags · ' : ''}${post.caption.split('\n').first}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white
                                .withAlpha(235),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Accordion timeline header ─────────────────────────────────────────
  Widget _buildTimelineHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's timeline",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            'Morning · Afternoon · Evening slots with platform icons.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayAccordion(BuildContext context, bool isDark,
      String dayKey, List<PostModel> dayPosts, int dayIndex) {
    final date = DateTime.parse(dayKey);
    final label = dayIndex == 0
        ? 'Today · ${DateFormat('EEE, MMM d').format(date)}'
        : DateFormat('EEEE, MMM d').format(date);
    final expanded = _expandedDays.contains(dayKey);
    final sorted = List<PostModel>.from(dayPosts)
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C22) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withAlpha(10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() {
                if (expanded) {
                  _expandedDays.remove(dayKey);
                } else {
                  _expandedDays.add(dayKey);
                }
              }),
              borderRadius: BorderRadius.circular(26),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: UniversalMediaPlayer(
                          mediaUrl: sorted.first.mediaUrl,
                          isVideo: sorted.first.isVideo,
                          autoPlay: false,
                          showControls: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${dayIndex + 1}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white38
                                  : Colors.black38,
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${sorted.length} posts · ${DateFormat('h:mm a').format(sorted.first.scheduledTime)} start',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration:
                          const Duration(milliseconds: 200),
                      child: Icon(
                        CupertinoIcons.chevron_down,
                        size: 18,
                        color: isDark
                            ? Colors.white60
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white12
                      : Colors.black.withAlpha(8)),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  children: [
                    for (final p in sorted)
                      _slotRow(context, isDark, p),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slotRow(BuildContext context, bool isDark, PostModel post) {
    final hour = post.scheduledTime.hour;
    final slot = hour < 12
        ? 'Morning'
        : (hour < 17 ? 'Afternoon' : 'Evening');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: post.platformInfo.color
                      .withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  post.isVideo
                      ? CupertinoIcons.videocam_fill
                      : CupertinoIcons.photo_fill,
                  size: 14,
                  color: post.platformInfo.color,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? Colors.white38
                            : Colors.black38,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  '${DateFormat('h:mm a').format(post.scheduledTime)} · ${post.platformInfo.name} · ${post.caption.split('\n').first}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color:
                        isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '#${_hashtagCount(post.caption)} tags · ${post.status}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark
                        ? Colors.white38
                        : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            color: isDark
                ? Colors.white.withAlpha(14)
                : Colors.black.withAlpha(7),
            borderRadius: BorderRadius.circular(10),
            onPressed: () => _openQuickEdit(context, post),
            child: Text('Edit',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Colors.white
                        : Colors.black87)),
          ),
        ],
      ),
    );
  }
}

/// Floating bottom-sheet quick-edit modal (trip-suggestion sheet pattern).
class _QuickEditSheet extends StatefulWidget {
  final PostModel post;
  const _QuickEditSheet({required this.post});

  @override
  State<_QuickEditSheet> createState() => _QuickEditSheetState();
}

class _QuickEditSheetState extends State<_QuickEditSheet> {
  late TextEditingController _caption;
  late String _status;

  @override
  void initState() {
    super.initState();
    _caption = TextEditingController(text: widget.post.caption);
    _status = widget.post.status;
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E26).withAlpha(245)
                  : Colors.white.withAlpha(248),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(24)
                    : Colors.black.withAlpha(8),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: UniversalMediaPlayer(
                          mediaUrl: widget.post.mediaUrl,
                          isVideo: widget.post.isVideo,
                          autoPlay: false,
                          showControls: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(widget.post.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black)),
                          Text(
                            '${DateFormat('EEE, MMM d · h:mm a').format(widget.post.scheduledTime)} · ${widget.post.platformInfo.name}',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 22),
                      color: isDark
                          ? Colors.white38
                          : Colors.black26,
                      onPressed: () =>
                          Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _caption,
                  maxLines: 4,
                  minLines: 3,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white
                          : Colors.black87),
                  decoration: InputDecoration(
                    hintText:
                        'Tweak caption without leaving the grid…',
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.black.withAlpha(5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final s in [
                      'scheduled',
                      'draft',
                      'published'
                    ])
                      Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s,
                              style: const TextStyle(
                                  fontSize: 11.5)),
                          selected: _status == s,
                          onSelected: (_) =>
                              setState(() => _status = s),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 13),
                        color: isDark
                            ? Colors.white.withAlpha(14)
                            : Colors.black.withAlpha(7),
                        borderRadius:
                            BorderRadius.circular(16),
                        onPressed: () =>
                            Navigator.of(context).pop(),
                        child: Text('Cancel',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: CupertinoButton.filled(
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 13),
                        borderRadius:
                            BorderRadius.circular(16),
                        onPressed: () {
                          context
                              .read<PostsProvider>()
                              .updatePost(widget.post.copyWith(
                                caption: _caption.text.trim().isEmpty
                                    ? widget.post.caption
                                    : _caption.text.trim(),
                                status: _status,
                              ));
                          Navigator.of(context).pop();
                        },
                        child: const Text('Save changes',
                            style: TextStyle(
                                fontWeight:
                                    FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
