import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../providers/posts_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/dynamic_capsule.dart';
import '../widgets/media_player_widget.dart';
import '../widgets/media_picker_dialog.dart';

class SimulatorView extends StatefulWidget {
  const SimulatorView({super.key});

  @override
  State<SimulatorView> createState() => _SimulatorViewState();
}

class _SimulatorViewState extends State<SimulatorView> {
  SocialPlatform _selectedPlatform = SocialPlatform.instagram;
  bool _isReelMode = true; // For Instagram: Reel vs Feed
  String? _selectedPostId;

  // Temporary overridden media for testing
  String? _customMediaUrl;
  bool? _customIsVideo;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsProvider = context.watch<PostsProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.activeProfile;
    final posts = postsProvider.posts;

    // Determine currently displayed post
    PostModel activePost;
    if (_selectedPostId != null) {
      activePost = posts.firstWhere(
        (p) => p.id == _selectedPostId,
        orElse: () => posts.first,
      );
    } else {
      activePost = posts.isNotEmpty ? posts.first : _createDefaultPost();
    }

    final mediaUrl = _customMediaUrl ?? activePost.mediaUrl;
    final isVideo = _customIsVideo ?? activePost.isVideo;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Sidebar Controls & Post Selector
          Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Device Simulator',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const DynamicCapsule(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Real-time iPhone preview across networks with genuine media playback.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Platform Selector Tabs
                  Text(
                    'TARGET PLATFORM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPlatformChip(SocialPlatform.instagram, 'Instagram', CupertinoIcons.camera),
                      _buildPlatformChip(SocialPlatform.tiktok, 'TikTok', CupertinoIcons.music_note_2),
                      _buildPlatformChip(SocialPlatform.youtube, 'YT Shorts', CupertinoIcons.play_rectangle),
                      _buildPlatformChip(SocialPlatform.facebook, 'Facebook', CupertinoIcons.bubble_left_bubble_right),
                    ],
                  ),

                  if (_selectedPlatform == SocialPlatform.instagram) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Format:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 10),
                        CupertinoSlidingSegmentedControl<bool>(
                          groupValue: _isReelMode,
                          children: const {
                            true: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: Text('Reels (9:16)', style: TextStyle(fontSize: 12)),
                            ),
                            false: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              child: Text('Feed (1:1)', style: TextStyle(fontSize: 12)),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) setState(() => _isReelMode = val);
                          },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Media Testing Controls
                  Text(
                    'ACTIVE MEDIA & TESTING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppleGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.photo_fill,
                              color: isVideo ? AppleTheme.systemPurple : AppleTheme.systemTeal,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                mediaUrl.split('/').last,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: AppleTheme.systemBlue,
                          borderRadius: BorderRadius.circular(10),
                          onPressed: () async {
                            final res = await MediaPickerDialog.show(context);
                            if (res != null) {
                              setState(() {
                                _customMediaUrl = res.pathOrUrl;
                                _customIsVideo = res.isVideo;
                              });
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.arrow_2_squarepath, size: 14),
                              SizedBox(width: 6),
                              Text('Swap Media (File / Sample)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Post Selector list
                  Text(
                    'SELECT QUEUE POST TO PREVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...posts.map((p) {
                    final isSelected = p.id == activePost.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AppleGlassCard(
                        padding: const EdgeInsets.all(10),
                        customBorder: isSelected
                            ? Border.all(color: AppleTheme.systemBlue, width: 1.5)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedPostId = p.id;
                            _customMediaUrl = null;
                            _customIsVideo = null;
                          });
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: UniversalMediaPlayer(
                                  mediaUrl: p.mediaUrl,
                                  isVideo: p.isVideo,
                                  autoPlay: false,
                                  showControls: false,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: p.platformInfo.color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          p.platformInfo.name,
                                          style: TextStyle(
                                            color: p.platformInfo.color,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (p.isVideo)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: AppleTheme.systemPurple.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'VIDEO',
                                            style: TextStyle(
                                              color: AppleTheme.systemPurple,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    p.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Main Stage: Apple iPhone Mockup
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: _buildIPhoneMockup(activePost, mediaUrl, isVideo, profile?.name ?? 'Emms Digital Media', profile?.instagramHandle ?? '@emmsdigitalmedia'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip(SocialPlatform platform, String label, IconData icon) {
    final isSelected = _selectedPlatform == platform;
    final color = PlatformInfo.fromPlatform(platform).color;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: color,
      onSelected: (selected) {
        if (selected) setState(() => _selectedPlatform = platform);
      },
    );
  }

  Widget _buildIPhoneMockup(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Container(
      width: 380,
      height: 780,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(43),
        child: Stack(
          children: [
            // Screen Content by Platform
            Positioned.fill(
              child: _renderPlatformScreen(post, mediaUrl, isVideo, authorName, handle),
            ),

            // Top Dynamic Island Notch
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 120,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A24),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF282834), width: 1.5),
                        ),
                      ),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Home Bar Indicator
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 130,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderPlatformScreen(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    switch (_selectedPlatform) {
      case SocialPlatform.instagram:
        return _isReelMode
            ? _buildInstagramReel(post, mediaUrl, isVideo, authorName, handle)
            : _buildInstagramFeed(post, mediaUrl, isVideo, authorName, handle);
      case SocialPlatform.tiktok:
        return _buildTikTok(post, mediaUrl, isVideo, authorName, handle);
      case SocialPlatform.youtube:
        return _buildYouTubeShorts(post, mediaUrl, isVideo, authorName, handle);
      case SocialPlatform.facebook:
        return _buildFacebookPost(post, mediaUrl, isVideo, authorName, handle);
      default:
        return _buildInstagramReel(post, mediaUrl, isVideo, authorName, handle);
    }
  }

  // 1. INSTAGRAM REEL (9:16 Full Screen Vertical)
  Widget _buildInstagramReel(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Stack(
      children: [
        // Video/Media Surface
        Positioned.fill(
          child: UniversalMediaPlayer(
            mediaUrl: mediaUrl,
            isVideo: isVideo,
            fit: BoxFit.cover,
            autoPlay: true,
            showControls: true,
          ),
        ),

        // Gradient overlay bottom & top
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.85),
                ],
                stops: const [0.0, 0.15, 0.55, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Header
        Positioned(
          top: 48,
          left: 18,
          right: 18,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reels',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              const Icon(CupertinoIcons.camera, color: Colors.white, size: 24),
            ],
          ),
        ),

        // Right Action Bar
        Positioned(
          right: 14,
          bottom: 70,
          child: Column(
            children: [
              _buildMetricIcon(CupertinoIcons.heart_fill, '${post.likesCount > 0 ? post.likes : "2.8K"}', Colors.redAccent),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.bubble_left_fill, '${post.comments > 0 ? post.comments : "142"}', Colors.white),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.paperplane_fill, 'Share', Colors.white),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.ellipsis, '', Colors.white),
              const SizedBox(height: 16),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/emms_avatar.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Info
        Positioned(
          left: 16,
          right: 80,
          bottom: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 17,
                    backgroundImage: AssetImage('assets/emms_avatar.png'),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    handle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.caption,
                style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(CupertinoIcons.music_note, color: Colors.white, size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'Original audio - $authorName',
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. INSTAGRAM FEED (Header, 1:1 Media, Actions, Caption)
  Widget _buildInstagramFeed(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          const SizedBox(height: 48),
          // IG Feed Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const CircleAvatar(radius: 16, backgroundImage: AssetImage('assets/emms_avatar.png')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(handle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Nairobi, Kenya', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10.5)),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.ellipsis, color: Colors.white, size: 18),
              ],
            ),
          ),

          // Media container (Square/Tall)
          Expanded(
            child: UniversalMediaPlayer(
              mediaUrl: mediaUrl,
              isVideo: isVideo,
              fit: BoxFit.cover,
              autoPlay: true,
              showControls: true,
            ),
          ),

          // IG Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(CupertinoIcons.heart, color: Colors.white, size: 24),
                    const SizedBox(width: 16),
                    const Icon(CupertinoIcons.bubble_left, color: Colors.white, size: 23),
                    const SizedBox(width: 16),
                    const Icon(CupertinoIcons.paperplane, color: Colors.white, size: 23),
                  ],
                ),
                const Icon(CupertinoIcons.bookmark, color: Colors.white, size: 23),
              ],
            ),
          ),

          // Likes & Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${post.likesCount > 0 ? post.likes : 842} likes',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                    children: [
                      TextSpan(text: '$handle ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: post.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. TIKTOK
  Widget _buildTikTok(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Stack(
      children: [
        Positioned.fill(
          child: UniversalMediaPlayer(
            mediaUrl: mediaUrl,
            isVideo: isVideo,
            fit: BoxFit.cover,
            autoPlay: true,
            showControls: true,
          ),
        ),
        // TikTok Action Bar
        Positioned(
          right: 12,
          bottom: 60,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  const CircleAvatar(radius: 20, backgroundImage: AssetImage('assets/emms_avatar.png')),
                  Positioned(
                    bottom: -3,
                    child: Container(
                      decoration: const BoxDecoration(color: Color(0xFFFE2C55), shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(CupertinoIcons.plus, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.heart_fill, '${post.likesCount > 0 ? post.likes : "12.4K"}', Colors.white),
              const SizedBox(height: 16),
              _buildMetricIcon(CupertinoIcons.bubble_left_fill, '${post.comments > 0 ? post.comments : "389"}', Colors.white),
              const SizedBox(height: 16),
              _buildMetricIcon(CupertinoIcons.bookmark_fill, '1.2K', Colors.white),
              const SizedBox(height: 16),
              _buildMetricIcon(CupertinoIcons.arrowshape_turn_up_right_fill, 'Share', Colors.white),
              const SizedBox(height: 18),
              // Spinning Record Disc
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: const Center(
                  child: CircleAvatar(radius: 8, backgroundImage: AssetImage('assets/emms_avatar.png')),
                ),
              ),
            ],
          ),
        ),

        // Caption info
        Positioned(
          left: 14,
          right: 76,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(handle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                post.caption,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(CupertinoIcons.music_note_2, size: 12, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Trending Story Sound - Emms', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. YOUTUBE SHORTS
  Widget _buildYouTubeShorts(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Stack(
      children: [
        Positioned.fill(
          child: UniversalMediaPlayer(
            mediaUrl: mediaUrl,
            isVideo: isVideo,
            fit: BoxFit.cover,
            autoPlay: true,
            showControls: true,
          ),
        ),
        // YouTube Action Column
        Positioned(
          right: 12,
          bottom: 60,
          child: Column(
            children: [
              _buildMetricIcon(CupertinoIcons.hand_thumbsup_fill, '${post.likesCount > 0 ? post.likes : "3.1K"}', Colors.white),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.hand_thumbsdown, 'Dislike', Colors.white),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.bubble_left_bubble_right_fill, '${post.comments > 0 ? post.comments : "95"}', Colors.white),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.arrowshape_turn_up_right_fill, 'Share', Colors.white),
              const SizedBox(height: 18),
              _buildMetricIcon(CupertinoIcons.arrow_2_squarepath, 'Remix', Colors.white),
            ],
          ),
        ),

        // Author & Subscribe
        Positioned(
          left: 14,
          right: 80,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 16, backgroundImage: AssetImage('assets/emms_avatar.png')),
                  const SizedBox(width: 8),
                  Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
                    child: const Text('Subscribe', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.caption,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 5. FACEBOOK POST
  Widget _buildFacebookPost(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Container(
      color: const Color(0xFF242526),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Facebook Post Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const CircleAvatar(radius: 18, backgroundImage: AssetImage('assets/emms_avatar.png')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                      Row(
                        children: [
                          Text('2 hrs ago • ', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                          Icon(CupertinoIcons.globe, color: Colors.white.withOpacity(0.6), size: 11),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.ellipsis, color: Colors.white, size: 20),
              ],
            ),
          ),

          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              post.caption,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Media container
          Expanded(
            child: UniversalMediaPlayer(
              mediaUrl: mediaUrl,
              isVideo: isVideo,
              fit: BoxFit.cover,
              autoPlay: true,
              showControls: true,
            ),
          ),

          // Action counts & button bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Color(0xFF1877F2), shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.hand_thumbsup_fill, color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 6),
                    Text('${post.likesCount > 0 ? post.likes : 124}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
                Text('${post.comments > 0 ? post.comments : 32} comments', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFbButton(CupertinoIcons.hand_thumbsup, 'Like'),
                _buildFbButton(CupertinoIcons.bubble_left, 'Comment'),
                _buildFbButton(CupertinoIcons.arrowshape_turn_up_right, 'Share'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFbButton(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMetricIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ],
    );
  }

  PostModel _createDefaultPost() {
    return PostModel(
      id: 'default',
      caption: 'I create engaging storytelling reels tailored to your business—crafted to grab attention.',
      scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      platform: SocialPlatform.instagram,
      mediaUrl: 'assets/samples/emms_storytelling_reel.mp4',
      isVideo: true,
      likes: '2818',
      comments: 142,
    );
  }
}
