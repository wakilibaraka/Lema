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
import '../widgets/dynamic_capsule.dart';
import '../widgets/media_player_widget.dart';
import '../widgets/media_picker_dialog.dart';

class QueueView extends StatefulWidget {
  const QueueView({super.key});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  int _selectedSegment = 0; // 0: Queue, 1: Published History

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
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publishing Queue',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buffer / Crowdfire cadence with auto-posting slots & instantaneous dispatch.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const DynamicCapsule(),
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
              ],
            ),

            const SizedBox(height: 20),

            // Queue Slots Overview Strip
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: queueSlots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final slot = queueSlots[index];
                  return _buildSlotCard(slot, isDark);
                },
              ),
            ),

            const SizedBox(height: 20),

            // Segment Control: Queue vs Published
            Row(
              children: [
                CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedSegment,
                  children: {
                    0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Scheduled Queue (${scheduledPosts.length})', style: const TextStyle(fontSize: 13)),
                    ),
                    1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text('Published History (${publishedPosts.length})', style: const TextStyle(fontSize: 13)),
                    ),
                  },
                  onValueChanged: (val) {
                    if (val != null) setState(() => _selectedSegment = val);
                  },
                ),
                const Spacer(),
                if (_selectedSegment == 0 && scheduledPosts.isNotEmpty)
                  Text(
                    'Next post scheduled in approx. 45 mins',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                  ),
              ],
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
              color: (slot.isActive ? AppleTheme.systemBlue : Colors.grey).withOpacity(0.12),
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = posts[index];
        final formattedDate = DateFormat('EEE, MMM d • h:mm a').format(post.scheduledTime);

        return AppleGlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Preview Box
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 90,
                  height: 90,
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
                              color: Colors.black.withOpacity(0.7),
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
                    // Platform and Schedule Badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: post.platformInfo.color.withOpacity(0.15),
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.clock, size: 11, color: isDark ? Colors.white60 : Colors.black54),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (post.status == PostStatus.published) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppleTheme.systemGreen.withOpacity(0.15),
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

                    // Media File Info
                    Text(
                      'Asset: ${post.mediaUrl.split('/').last}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isScheduled)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      color: AppleTheme.systemBlue,
                      borderRadius: BorderRadius.circular(10),
                      onPressed: () {
                        context.read<PostsProvider>().publishNow(post.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Dispatched to ${post.platformInfo.name} via Daemon!')),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.paperplane_fill, size: 13),
                          SizedBox(width: 6),
                          Text('Share Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    onPressed: () {
                      context.read<PostsProvider>().deletePost(post.id);
                    },
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppleTheme.systemRed.withOpacity(0.9),
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
                color: Colors.black.withOpacity(0.4),
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
                    fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
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
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
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
