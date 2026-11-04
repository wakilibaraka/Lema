import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/destinations.dart';
import '../core/models/platform_info.dart';
import '../core/models/post_model.dart';
import '../core/models/queue_slot_model.dart';
import '../core/providers/app_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/posts_provider.dart';
import '../core/services/analytics_service.dart';
import '../features/analytics/metrics.dart';
import '../theme/backdrop_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/lema_pill.dart';
import '../widgets/lema_toast.dart';
import '../widgets/media_player_widget.dart';
import '../widgets/media_picker_dialog.dart';
import '../widgets/schedule_time_picker.dart';

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

  Future<void> _dispatch(PostModel post) async {
    if (_sending.contains(post.id)) return;
    setState(() => _sending.add(post.id));
    // Short beat so Sending is perceivable; the request itself is real.
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final result = await context.read<PostsProvider>().publishNow(post.id);
    if (!mounted) return;

    setState(() => _sending.remove(post.id));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSent
              // The label travels with the result so demo mode never claims
              // a real daemon send.
              ? (result.detail ??
                    'Dispatched to ${post.platformInfo.name} via daemon')
              : 'Not sent — ${result.toString()}',
        ),
      ),
    );
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar (bound the title column so the
            // 263px subtitle can never overflow narrow mobile widths).
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Queue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // Compact 22pt H1 fits beside Create Post
                          // at 402pt (the 26pt title truncated to "Qu…").
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Buffer / Crowdfire cadence with auto-posting slots & instantaneous dispatch.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => _showComposeModal(context),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.plus_circle_fill, size: 16),
                      SizedBox(width: 8),
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

            const SizedBox(height: 20),

            // Queue Slots Overview Strip
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: queueSlots.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final slot = queueSlots[index];
                  return _buildSlotCard(slot, isDark);
                },
              ),
            ),

            const SizedBox(height: 20),

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
                    const SizedBox(width: 8),
                    LemaPill(
                      label: 'Published (${publishedPosts.length})',
                      selected: _selectedSegment == 1,
                      onTap: () => setState(() => _selectedSegment = 1),
                      isDark: isDark,
                    ),
                    if (_selectedSegment == 0 && scheduledPosts.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Center(
                        child: Text(
                          _nextSlotLabel(scheduledPosts, overdue.length),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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

            // Overdue band: the parked daemon never advances the clock on
            // its own, so slots that have already passed are called out
            // here instead of silently sitting in the queue.
            if (_selectedSegment == 0 && overdue.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildOverdueBand(isDark, overdue.length),
            ],

            const SizedBox(height: 16),

            // Content List
            Expanded(
              child: _selectedSegment == 0
                  ? _buildPostsList(
                      scheduledPosts,
                      isDark,
                      isScheduled: true,
                      failed: failedPosts,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 14,
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 18,
            color: BackdropTheme.statusWarning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 scheduled post missed its slot. The daemon never fired it.'
                  : '$count scheduled posts missed their slots. The daemon never fired them.',
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

  Widget _buildSlotCard(QueueSlotModel slot, bool isDark) {
    return AppleGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (slot.isActive ? BackdropTheme.accent : Colors.grey)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.clock_fill,
              size: 16,
              color: slot.isActive ? BackdropTheme.accent : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                slot.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                slot.formattedTime,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 6),
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
        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
              padding: const EdgeInsets.only(bottom: 12),
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
        padding: const EdgeInsets.only(bottom: 12),
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
      padding: const EdgeInsets.all(16),
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
                            padding: const EdgeInsets.all(4),
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

              const SizedBox(width: 16),

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
                            horizontal: 8,
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
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
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
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
                    const SizedBox(height: 6),
                    // Schedule line: bounded by the Expanded column, so the
                    // date ellipsizes instead of overflowing narrow cards.
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          size: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        const SizedBox(width: 4),
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

                    const SizedBox(height: 8),

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

                    const SizedBox(height: 8),

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
            const SizedBox(height: 8),
            Text(
              'Not sent: ${post.failureReason ?? 'no reason recorded'}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
          if (post.recurrence != recurrenceNone) ...[
            const SizedBox(height: 8),
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
            const SizedBox(height: 8),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
          const SizedBox(height: 12),

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
                  horizontal: 10,
                  vertical: 6,
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onPressed: null,
        child: CupertinoActivityIndicator(radius: 9),
      );
    }
    if (post.status == 'failed') {
      return Tooltip(
        message: post.failureReason ?? 'Publish failed',
        child: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          onPressed: () => _dispatch(post),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.refresh, size: 13, color: Colors.red),
              SizedBox(width: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
          SizedBox(width: 6),
          Text(
            'Share Now',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _showComposeModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => const _ComposePostModal(),
    );
  }
}

class _ComposePostModal extends StatefulWidget {
  const _ComposePostModal();

  @override
  State<_ComposePostModal> createState() => _ComposePostModalState();
}

class _ComposePostModalState extends State<_ComposePostModal> {
  final TextEditingController _captionController = TextEditingController();
  SocialPlatform _platform = SocialPlatform.instagram;
  String _mediaUrl = 'assets/samples/emms_storytelling_reel.mp4';
  bool _isVideo = true;
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 3));
  String _recurrence = recurrenceNone;
  final Set<int> _days = {};

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _submit({bool asDraft = false}) {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) return;

    final newPost = PostModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      caption: caption,
      scheduledTime: _scheduledTime,
      platform: _platform,
      mediaUrl: _mediaUrl,
      isVideo: _isVideo,
      status: asDraft ? 'draft' : 'scheduled',
      recurrence: _recurrence,
      recurrenceDays: _recurrence == recurrenceWeekly
          ? _days.toList()
          : const [],
    );

    context.read<PostsProvider>().addPost(newPost);
    Navigator.of(context).pop();
    LemaToast.show(
      context,
      asDraft ? 'Saved as draft' : 'Added to the queue',
      kind: asDraft ? LemaToastKind.saved : LemaToastKind.moved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      // Scrollable so the extra schedule row can never overflow a short
      // window or a 402pt phone.
      child: SingleChildScrollView(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 580,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(BackdropTheme.radiusCard),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create New Post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 22,
                        ),
                        color: isDark ? Colors.white38 : Colors.black26,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Platform picker
                  Wrap(
                    spacing: 8,
                    children: SocialPlatform.values.map((p) {
                      final isSel = _platform == p;
                      final info = PlatformInfo.fromPlatform(p);
                      return ChoiceChip(
                        label: Text(info.name),
                        selected: isSel,
                        selectedColor: info.color,
                        onSelected: (sel) {
                          if (sel) setState(() => _platform = p);
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Caption
                  TextField(
                    controller: _captionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Craft your high-converting caption, hooks, or call-to-action...',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Media Selector
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: UniversalMediaPlayer(
                            mediaUrl: _mediaUrl,
                            isVideo: _isVideo,
                            autoPlay: false,
                            showControls: false,
                            thumbnail: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mediaUrl.split('/').last,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _isVideo
                                  ? 'Video Clip (MP4/MOV)'
                                  : 'Still Graphic (PNG/JPG)',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        onPressed: () async {
                          final res = await MediaPickerDialog.show(context);
                          if (res != null) {
                            setState(() {
                              _mediaUrl = res.pathOrUrl;
                              _isVideo = res.isVideo;
                            });
                          }
                        },
                        child: Text(
                          'Change Media',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Schedule row: this modal used to hard-code "three hours from
                  // now" with no way to see or change it.
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.clock,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Schedule: ${formatScheduleSlot(_scheduledTime)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        onPressed: () async {
                          final picked = await showScheduleTimePicker(
                            context: context,
                            initial: _scheduledTime,
                          );
                          if (picked != null && mounted) {
                            setState(() => _scheduledTime = picked);
                          }
                        },
                        child: Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11,
                            color: BackdropTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Repeat: with no days picked, weekly uses the scheduled day.
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (value, label) in const [
                        (recurrenceNone, 'Once'),
                        (recurrenceDaily, 'Daily'),
                        (recurrenceWeekly, 'Weekly'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _recurrence == value,
                          onSelected: (_) =>
                              setState(() => _recurrence = value),
                        ),
                    ],
                  ),
                  if (_recurrence == recurrenceWeekly) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          FilterChip(
                            label: Text(
                              DateFormat.E().format(DateTime(2024, 1, d)),
                            ),
                            selected: _days.contains(d),
                            onSelected: (on) => setState(
                              () => on ? _days.add(d) : _days.remove(d),
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () => _submit(asDraft: true),
                          child: Text(
                            'Save as Draft',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CupertinoButton.filled(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: _submit,
                          child: const Text(
                            'Add to Queue',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
