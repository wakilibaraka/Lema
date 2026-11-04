import 'package:flutter/cupertino.dart';
import '../core/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/services/api_service.dart';

import '../core/destinations.dart';
import '../core/models/post_model.dart';
import '../core/providers/app_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/posts_provider.dart';
import '../core/services/analytics_service.dart';
import '../features/analytics/metrics.dart';
import '../theme/backdrop_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/lema_pill.dart';
import '../widgets/media_player_widget.dart';

class QueueView extends StatefulWidget {
  const QueueView({super.key});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  int _selectedSegment = 0; // 0: Queue, 1: Published History

  /// Posts with a request in flight. A failed attempt is saved on the post,
  /// so it survives a restart and carries its reason.
  final Set<String> _sending = {};
  List<String> _expired = const [];

  Future<void> _dispatch(PostModel post, {bool confirmedNotPosted = false}) async {
    if (_sending.contains(post.id)) return;
    setState(() => _sending.add(post.id));
    // Short beat so Sending is perceivable; the request itself is real.
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final result = await context.read<PostsProvider>().publishNow(post.id, confirmedNotPosted: confirmedNotPosted);
    if (!mounted) return;

    setState(() => _sending.remove(post.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          switch (result.outcome) {
            // The label travels with the result so demo mode never claims
            // a real send.
            DispatchOutcome.published =>
              result.detail ?? 'Published to ${post.platformInfo.name}',
            DispatchOutcome.failed => 'Not sent: $result',
            DispatchOutcome.unknown => 'Result unknown: $result',
          },
        ),
      ),
    );
  }

  /// An unknown result is settled by the user looking at the platform. This
  /// is the only way to resend one, so nothing posts twice by accident.
  Future<void> _checkResult(PostModel post) async {
    final posted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Did this reach ${post.platformInfo.name}?'),
        content: Text(
          '${post.failureReason ?? 'Lema did not get an answer.'}\n\n'
          'Look for the post on ${post.platformInfo.name}, then tell Lema what you found.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not there, send again'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('It posted'),
          ),
        ],
      ),
    );
    if (posted == null || !mounted) return;
    if (posted) {
      context.read<PostsProvider>().confirmPosted(post.id);
    } else {
      await _dispatch(post, confirmedNotPosted: true);
    }
  }

  void _autoSlot(PostsProvider posts) {
    final rows = buildMetrics(posts.publishedPosts, {
      for (final p in posts.publishedPosts)
        p.id: PostAnalytics(
          postId: p.id,
          platform: p.primaryPlatform.name,
          likes: AnalyticsService.parseCompactCount(p.likes),
          views: AnalyticsService.parseCompactCount(p.views),
          comments: p.comments,
          fromStoredCounts: true,
        ),
    });
    final placed = posts.autoSlotDrafts(bestHours(rows));
    _offerUndo(
      posts,
      placed == 0
          ? 'No open days to slot drafts into'
          : 'Scheduled $placed ${placed == 1 ? 'draft' : 'drafts'} into open days',
      canUndo: placed > 0,
    );
  }

  void _offerUndo(PostsProvider posts, String message, {bool canUndo = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: canUndo
              ? SnackBarAction(label: 'Undo', onPressed: posts.undoLastReorder)
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsProvider = context.watch<PostsProvider>();
    final scheduledPosts = postsProvider.queuePosts;
    final failedPosts = postsProvider.failedPosts;
    final drafts = postsProvider.draftPosts;
    _expired = context.watch<AuthProvider>().expiredPlatforms;
    final publishedPosts = postsProvider.publishedPosts;
    final queueSlots = postsProvider.queueSlots;
    final overdue = postsProvider.overduePosts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(LemaTheme.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The tab above names this screen, so the first row is its controls.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daily slots: ${queueSlots.map((slot) => '${slot.name} ${slot.formattedTime}').join(' · ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: LemaTheme.s3),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LemaTheme.s4,
                    vertical: LemaTheme.s3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => context.read<AppProvider>().setNavIndex(composerDestinationIndex),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.plus_circle_fill, size: 16),
                      SizedBox(width: LemaTheme.s2),
                      Text(
                        'Create Post',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: LemaTheme.s4),

            // Segment pills (Home language): the sliding control's
            // fixed labels clipped at 402pt ("Published History (0…"), so the
            // segments become scrollable pills with the same edge fade.
            SizedBox(
              height: 44,
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0.0, 0.92, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    LemaPill(
                      label: 'Scheduled (${scheduledPosts.length})',
                      selected: _selectedSegment == 0,
                      onTap: () => setState(() => _selectedSegment = 0),
                      isDark: isDark,
                    ),
                    const SizedBox(width: LemaTheme.s2),
                    LemaPill(
                      label: 'Published (${publishedPosts.length})',
                      selected: _selectedSegment == 1,
                      onTap: () => setState(() => _selectedSegment = 1),
                      isDark: isDark,
                    ),
                    if (_selectedSegment == 0 && scheduledPosts.isNotEmpty) ...[
                      const SizedBox(width: LemaTheme.s3),
                      Center(
                        child: Text(
                          _nextSlotLabel(scheduledPosts, overdue.length),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                      const SizedBox(width: LemaTheme.s2),
                    ],
                  ],
                ),
              ),
            ),

            if (_selectedSegment == 0 && drafts.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _autoSlot(postsProvider),
                  child: Text(
                    'Auto-slot ${drafts.length} ${drafts.length == 1 ? 'draft' : 'drafts'}',
                  ),
                ),
              ),

            // Overdue band: the daemon can be off or the Mac asleep, so slots that have already passed are called out
            // here instead of silently sitting in the queue.
            if (_selectedSegment == 0 && overdue.isNotEmpty) ...[
              const SizedBox(height: LemaTheme.s3),
              _buildOverdueBand(isDark, overdue.length),
            ],

            const SizedBox(height: LemaTheme.s4),

            // Content List
            Expanded(
              child: _selectedSegment == 0
                  ? _buildPostsList(
                      scheduledPosts,
                      isDark,
                      isScheduled: true,
                      failed: [...postsProvider.unknownPosts, ...failedPosts],
                    )
                  : _buildPostsList(publishedPosts, isDark, isScheduled: false),
            ),
          ],
        ),
      ),
    );
  }

  /// Amber-on-glass band listing how many slots have already passed. Uses a
  /// text label as well as colour, per the design plan's status rule.
  Widget _buildOverdueBand(bool isDark, int count) {
    return AppleGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: LemaTheme.s4, vertical: LemaTheme.s3),
      borderRadius: 14,
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 18,
            color: BackdropTheme.statusWarning,
          ),
          const SizedBox(width: LemaTheme.s3),
          Expanded(
            child: Text(
              count == 1
                  ? '1 scheduled post is past its slot. Posts only go out while the daemon is running and this Mac is awake.'
                  : '$count scheduled posts are past their slots. Posts only go out while the daemon is running and this Mac is awake.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(
    List<PostModel> posts,
    bool isDark, {
    required bool isScheduled,
    List<PostModel> failed = const [],
  }) {
    if (posts.isEmpty && failed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.square_stack_3d_down_right,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: LemaTheme.s3),
            Text(
              isScheduled
                  ? 'No Scheduled Posts in Queue'
                  : 'No Published Posts Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: LemaTheme.s2),
            Text(
              isScheduled
                  ? 'Click "Create Post" to add content to your next slot.'
                  : 'Publish posts from your queue to see them here.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }

    if (!isScheduled) {
      return ListView.separated(
        itemCount: posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: LemaTheme.s3),
        itemBuilder: (context, index) =>
            _buildPostCard(posts[index], isDark, isScheduled: false),
      );
    }

    // Failed posts sit above the queue and don't drag: they hold no slot.
    return ReorderableListView.builder(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final post in failed)
            Padding(
              padding: const EdgeInsets.only(bottom: LemaTheme.s3),
              child: _buildPostCard(post, isDark, isScheduled: true),
            ),
        ],
      ),
      itemCount: posts.length,
      onReorderItem: (from, to) {
        if (from == to) return;
        final provider = context.read<PostsProvider>();
        provider.reorderQueue(from, to);
        _offerUndo(provider, 'Queue order changed');
      },
      itemBuilder: (context, index) => Padding(
        key: ValueKey(posts[index].id),
        padding: const EdgeInsets.only(bottom: LemaTheme.s3),
        child: _buildPostCard(posts[index], isDark, isScheduled: true),
      ),
    );
  }

  Widget _buildPostCard(
    PostModel post,
    bool isDark, {
    required bool isScheduled,
  }) {
    final formattedDate = DateFormat('EEE, MMM d • h:mm a')
        .format(post.scheduledTime);
    final expiredChannels = post.expiredChannels(_expired);

    return AppleGlassCard(
      padding: const EdgeInsets.all(LemaTheme.s4),
      // Details row on top, actions span full width below.
      // Side-by-side actions squeezed the middle column to ~80pt at
      // 402pt and overflowed; stacked actions have no width pressure.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Preview Box (76pt keeps the details roomy).
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    children: [
                      UniversalMediaPlayer(
                        mediaUrl: post.mediaUrl,
                        isVideo: post.isVideo,
                        autoPlay: false,
                        showControls: false,
                        thumbnail: true,
                      ),
                      if (post.isVideo)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(LemaTheme.s1),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              CupertinoIcons.videocam_fill,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: LemaTheme.s4),

              // Post Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Platform + status chips (short, fixed-size — never overflow).
                    // Schedule line below is width-bounded with ellipsis.
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: LemaTheme.s2,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: post.platformInfo.color.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.platformInfo.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: post.platformInfo.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (post.status == 'published') ...[
                          const SizedBox(width: LemaTheme.s2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: LemaTheme.s2,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: BackdropTheme.statusOnline.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SENT',
                              style: TextStyle(
                                color: BackdropTheme.statusOnline,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (post.isOverdue) ...[
                          const SizedBox(width: LemaTheme.s2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: LemaTheme.s2,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: BackdropTheme.statusWarning.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(
                                color: BackdropTheme.statusWarning,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: LemaTheme.s2),
                    // Schedule line: bounded by the Expanded column, so the
                    // date ellipsizes instead of overflowing narrow cards.
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        const SizedBox(width: LemaTheme.s1),
                        Expanded(
                          child: Text(
                            formattedDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: LemaTheme.s2),

                    // Caption
                    Text(
                      post.caption,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: LemaTheme.s2),

                    // Media File Info (clamped — the unclamped
                    // filename was the 61px right-overflow).
                    Text(
                      'Asset: ${post.mediaUrl.split('/').last}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.status == 'failed') ...[
            const SizedBox(height: LemaTheme.s2),
            Text(
              'Not sent: ${post.failureReason ?? 'no reason recorded'}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          if (post.status == 'unknown') ...[
            const SizedBox(height: LemaTheme.s2),
            Text(
              'Result unknown: ${post.failureReason ?? 'check the platform'}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          if (post.recurrence != recurrenceNone) ...[
            const SizedBox(height: LemaTheme.s2),
            Text(
              post.recurrence == recurrenceDaily
                  ? 'Repeats daily'
                  : 'Repeats weekly',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
          if (isScheduled && expiredChannels.isNotEmpty) ...[
            const SizedBox(height: LemaTheme.s2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${expiredChannels.join(', ')}: connection expired, so this will not publish.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: LemaTheme.s3),
                  minimumSize: const Size(44, 44),
                  onPressed: () => context.read<AppProvider>().setNavIndex(
                    settingsDestinationIndex,
                  ),
                  child: const Text(
                    'Reconnect',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: LemaTheme.s3),

          // Action Buttons (dispatch states — Sending
          // spinner, Failed → Retry — fronting the parked daemon).
          // Actions span full width below the details: side-by-side
          // buttons squeezed the middle column at 402pt.
          Row(
            children: [
              if (isScheduled) Expanded(child: _dispatchButton(post, isDark)),
              if (!isScheduled) const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: LemaTheme.s3,
                  vertical: LemaTheme.s2,
                ),
                onPressed: () {
                  context.read<PostsProvider>().deletePost(post.id);
                },
                child: Text(
                  'Remove',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The next slot, computed from the real queue.
  /// This row used to read "Next post scheduled in approx. 45 mins" for every
  /// queue, whatever it actually held.
  String _nextSlotLabel(List<PostModel> scheduled, int overdueCount) {
    final now = DateTime.now();
    final upcoming =
        scheduled.where((p) => !p.scheduledTime.isBefore(now)).toList()
          ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    if (upcoming.isEmpty) {
      return overdueCount > 0
          ? 'Nothing left in the future — $overdueCount overdue'
          : 'Nothing scheduled yet';
    }

    final delta = upcoming.first.scheduledTime.difference(now);
    final when = delta.inHours >= 1
        ? '${delta.inHours}h ${delta.inMinutes % 60}m'
        : '${delta.inMinutes} min';
    return 'Next post in $when · ${upcoming.first.platformInfo.name}';
  }

  /// The dispatch button renders Queued → Sending → Sent, and
  /// Failed → Retry when `publishNow` reports a failed dispatch.
  Widget _dispatchButton(PostModel post, bool isDark) {
    if (_sending.contains(post.id)) {
      return const CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: LemaTheme.s4, vertical: LemaTheme.s2),
        onPressed: null,
        child: CupertinoActivityIndicator(radius: 9),
      );
    }
    if (post.status == 'unknown') {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: LemaTheme.s3, vertical: LemaTheme.s2),
        color: Colors.red.withValues(alpha: 0.12),
        foregroundColor: Colors.red,
        borderRadius: BorderRadius.circular(10),
        onPressed: () => _checkResult(post),
        child: const Text(
          'Check result',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (post.status == 'failed') {
      return Tooltip(
        message: post.failureReason ?? 'Publish failed',
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: LemaTheme.s3, vertical: LemaTheme.s2),
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          onPressed: () => _dispatch(post),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.refresh, size: 13, color: Colors.red),
              SizedBox(width: LemaTheme.s2),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: LemaTheme.s3, vertical: LemaTheme.s2),
      color: BackdropTheme.accent,
      // A plain (non-.filled) CupertinoButton defaults its foreground to
      // CupertinoTheme.primaryColor — #007AFF, the same value as the
      // background above — which rendered the label invisible.
      foregroundColor: Colors.white,
      borderRadius: BorderRadius.circular(10),
      onPressed: () => _dispatch(post),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.paperplane_fill, size: 13),
          SizedBox(width: LemaTheme.s2),
          Text(
            'Share Now',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
