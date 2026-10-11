import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../models/queue_slot_model.dart';
import '../providers/posts_provider.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/media_player_widget.dart';
import '../widgets/media_picker_dialog.dart';

class QueueView extends StatefulWidget {
  const QueueView({super.key});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  int _selectedSegment = 0; // 0: Queue, 1: Published History

  /// Slice 18: local dispatch states. The daemon interface is stubbed for
  /// the parked backend slice — these states already model Queued →
  /// Sending → Sent/Failed + Retry honestly (failures surface only from
  /// real `publishNow` errors, never simulated).
  final Set<String> _sending = {};
  final Map<String, String> _failed = {};

  Future<void> _dispatch(PostModel post) async {
    if (_sending.contains(post.id)) return;
    setState(() {
      _sending.add(post.id);
      _failed.remove(post.id);
    });
    // Simulated network beat so Sending is perceivable; the state machine
    // itself is real and will front the daemon later.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    try {
      context.read<PostsProvider>().publishNow(post.id);
      if (!mounted) return;
      setState(() => _sending.remove(post.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispatched to ${post.platformInfo.name} via Daemon!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending.remove(post.id);
        _failed[post.id] = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispatch failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsProvider = context.watch<PostsProvider>();
    final scheduledPosts = postsProvider.scheduledPosts;
    final publishedPosts = postsProvider.publishedPosts;
    final queueSlots = postsProvider.queueSlots;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar (Slice 3 drive-by: bound the title column so the
            // 263px subtitle can never overflow narrow mobile widths).
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publishing Queue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          // Slice 18: compact 22pt H1 fits beside Create Post
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => _showComposeModal(context),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.plus_circle_fill, size: 16),
                      SizedBox(width: 8),
                      Text('Create Post', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

            // Segment pills (Slice 18, Home language): the sliding control's
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
                    _segmentPill(
                        'Scheduled (${scheduledPosts.length})', 0, isDark),
                    const SizedBox(width: 8),
                    _segmentPill(
                        'Published (${publishedPosts.length})', 1, isDark),
                    if (_selectedSegment == 0 &&
                        scheduledPosts.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Center(
                        child: Text(
                          'Next post scheduled in approx. 45 mins',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : Colors.black45),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Content List
            Expanded(
              child: _selectedSegment == 0
                  ? _buildPostsList(scheduledPosts, isDark, isScheduled: true)
                  : _buildPostsList(publishedPosts, isDark, isScheduled: false),
            ),
          ],
        ),
      ),
    );
  }

  /// Slice 18: segment pill in the Home filter-pill language.
  Widget _segmentPill(String label, int index, bool isDark) {
    final selected = _selectedSegment == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSegment = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
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
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? (isDark ? Colors.black : Colors.white)
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
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
              color: (slot.isActive ? AppleTheme.systemBlue : Colors.grey).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              CupertinoIcons.clock_fill,
              size: 16,
              color: slot.isActive ? AppleTheme.systemBlue : Colors.grey,
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

  Widget _buildPostsList(List<PostModel> posts, bool isDark, {required bool isScheduled}) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.square_stack_3d_down_right, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(
              isScheduled ? 'No Scheduled Posts in Queue' : 'No Published Posts Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              isScheduled ? 'Click "Create Post" to add content to your next slot.' : 'Publish posts from your queue to see them here.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: posts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = posts[index];
        final formattedDate = DateFormat('EEE, MMM d • h:mm a').format(post.scheduledTime);

        return AppleGlassCard(
          padding: const EdgeInsets.all(16),
          // Slice 18: details row on top, actions span full width below.
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
                            child: const Icon(CupertinoIcons.videocam_fill, size: 12, color: Colors.white),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: post.platformInfo.color.withValues(alpha: 0.15),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppleTheme.systemGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SENT',
                              style: TextStyle(color: AppleTheme.systemGreen, fontSize: 10, fontWeight: FontWeight.w700),
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
                        Icon(CupertinoIcons.clock, size: 11, color: isDark ? Colors.white60 : Colors.black54),
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

                    // Media File Info (Slice 18: clamped — the unclamped
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
              const SizedBox(height: 12),

              // Action Buttons (Slice 18: dispatch states — Sending
              // spinner, Failed → Retry — fronting the parked daemon).
              // Actions span full width below the details: side-by-side
              // buttons squeezed the middle column at 402pt.
              Row(
                children: [
                  if (isScheduled) Expanded(child: _dispatchButton(post, isDark)),
                  if (!isScheduled) const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    onPressed: () {
                      context.read<PostsProvider>().deletePost(post.id);
                    },
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppleTheme.systemRed.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Slice 18: the dispatch button renders Queued → Sending → Sent, and
  /// Failed → Retry when `publishNow` itself throws.
  Widget _dispatchButton(PostModel post, bool isDark) {
    if (_sending.contains(post.id)) {
      return const CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onPressed: null,
        child: CupertinoActivityIndicator(radius: 9),
      );
    }
    if (_failed.containsKey(post.id)) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: AppleTheme.systemRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        onPressed: () => _dispatch(post),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.refresh, size: 13, color: AppleTheme.systemRed),
            SizedBox(width: 6),
            Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppleTheme.systemRed)),
          ],
        ),
      );
    }
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: AppleTheme.systemBlue,
      borderRadius: BorderRadius.circular(10),
      onPressed: () => _dispatch(post),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.paperplane_fill, size: 13),
          SizedBox(width: 6),
          Text('Share Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
  final DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 3));

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 580,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(AppleTheme.radiusXl),
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
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22),
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
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _isVideo ? 'Video Clip (MP4/MOV)' : 'Still Graphic (PNG/JPG)',
                            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
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

                const SizedBox(height: 24),

                // Submit Button
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    final caption = _captionController.text.trim();
                    if (caption.isEmpty) return;

                    final newPost = PostModel(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      caption: caption,
                      scheduledTime: _scheduledTime,
                      platform: _platform,
                      mediaUrl: _mediaUrl,
                      isVideo: _isVideo,
                    );

                    context.read<PostsProvider>().addPost(newPost);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Add to Publishing Queue', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
