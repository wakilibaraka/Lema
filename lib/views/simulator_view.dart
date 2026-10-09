import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/device_preview_model.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../providers/posts_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/device_frames/universal_device_frame.dart';
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

  // Multi-Device Simulation state
  DeviceCategory _selectedDeviceCategory = DeviceCategory.iphone;
  PreviewOrientation _deviceOrientation = PreviewOrientation.portrait;

  // Mobile layout tab: 0 = Device Preview, 1 = Controls & Settings
  int _mobileTab = 0;

  // Temporary overridden media for testing
  String? _customMediaUrl;
  bool? _customIsVideo;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
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
    final activeDeviceSpec = DeviceSpec.byCategory(_selectedDeviceCategory);

    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1250;
    final showInspector = screenWidth >= 1250;

    // Mobile View (< 768px): Segmented Switcher between Preview & Controls
    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Segmented Switcher for Mobile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131317) : Colors.white,
                border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoSegmentedControl<int>(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    children: const {
                      0: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.device_phone_portrait, size: 14),
                            SizedBox(width: 6),
                            Text('Device Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      1: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.slider_horizontal_3, size: 14),
                            SizedBox(width: 6),
                            Text('Controls & Media', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    },
                    groupValue: _mobileTab,
                    onValueChanged: (val) => setState(() => _mobileTab = val),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _mobileTab == 0
                  ? _buildDevicePreviewArea(
                      activeDeviceSpec,
                      activePost,
                      mediaUrl,
                      isVideo,
                      profile.name,
                      profile.instagramHandle,
                      isDark,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildControlsColumn(activePost, mediaUrl, isVideo, posts, isDark),
                    ),
            ),
          ],
        ),
      );
    }

    // Tablet & Desktop Responsive Layout (>= 768px)
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Controls & Post Selector (~330px)
          Container(
            width: isTablet ? 300 : 340,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131317).withAlpha(140) : Colors.white.withAlpha(160),
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: _buildControlsColumn(activePost, mediaUrl, isVideo, posts, isDark),
            ),
          ),

          // Center Device Preview Column (Auto-scaling with FittedBox)
          Expanded(
            child: _buildDevicePreviewArea(
              activeDeviceSpec,
              activePost,
              mediaUrl,
              isVideo,
              profile.name,
              profile.instagramHandle,
              isDark,
            ),
          ),

          // Right Creator Studio Inspector (Displays >= 1250px)
          if (showInspector)
            Container(
              width: 330,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131317).withAlpha(140) : Colors.white.withAlpha(160),
                border: Border(
                  left: BorderSide(
                    color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: _buildInspectorColumn(activePost, isDark),
              ),
            ),
        ],
      ),
    );
  }

  // Device Preview Area with Top Device Switcher Toolbar
  Widget _buildDevicePreviewArea(
    DeviceSpec activeDeviceSpec,
    PostModel activePost,
    String mediaUrl,
    bool isVideo,
    String authorName,
    String handle,
    bool isDark,
  ) {
    return Column(
      children: [
        // Top Multi-Device Switcher Toolbar
        _buildDeviceSwitcherToolbar(isDark),

        // Centered Auto-Scaling Device Frame (FittedBox prevents any window overflow)
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: UniversalDeviceFrame(
                  device: activeDeviceSpec,
                  orientation: _deviceOrientation,
                  isDark: isDark,
                  platform: _selectedPlatform,
                  post: activePost,
                  authorName: authorName,
                  handle: handle,
                  mediaUrl: mediaUrl,
                  isVideo: isVideo,
                  child: _renderPlatformScreen(activePost, mediaUrl, isVideo, authorName, handle),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Multi-Device Switcher Toolbar
  Widget _buildDeviceSwitcherToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(8),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Device Category Buttons
            ...DeviceSpec.allDevices.map((d) {
              final isSelected = _selectedDeviceCategory == d.category;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selectedDeviceCategory = d.category),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppleTheme.systemBlue.withAlpha(isDark ? 60 : 35)
                          : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppleTheme.systemBlue : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d.icon,
                          size: 14,
                          color: isSelected ? AppleTheme.systemBlue : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          d.name,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? (isDark ? Colors.white : AppleTheme.systemBlue) : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(width: 10),
            Container(width: 1, height: 20, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(width: 10),

            // Orientation Toggle (if supported)
            if (DeviceSpec.byCategory(_selectedDeviceCategory).supportsLandscape) ...[
              InkWell(
                onTap: () {
                  setState(() {
                    _deviceOrientation = _deviceOrientation == PreviewOrientation.portrait
                        ? PreviewOrientation.landscape
                        : PreviewOrientation.portrait;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _deviceOrientation == PreviewOrientation.portrait
                            ? CupertinoIcons.rectangle_dock
                            : CupertinoIcons.rectangle_grid_1x2,
                        size: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _deviceOrientation == PreviewOrientation.portrait ? 'Portrait' : 'Landscape',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Active Device Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppleTheme.systemGreen.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppleTheme.systemGreen, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(
                    '${DeviceSpec.byCategory(_selectedDeviceCategory).brand} Live Canvas',
                    style: const TextStyle(color: AppleTheme.systemGreen, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Left Controls Column
  Widget _buildControlsColumn(
    PostModel activePost,
    String mediaUrl,
    bool isVideo,
    List<PostModel> posts,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Simulator',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Preview on iPhone, Android, Tablet, Laptop, and TV.',
          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
        ),

        const SizedBox(height: 18),

        // Platform Selector Tabs
        Text(
          'TARGET PLATFORM',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildPlatformChip(SocialPlatform.instagram, 'Instagram', CupertinoIcons.camera, isDark),
            _buildPlatformChip(SocialPlatform.tiktok, 'TikTok', CupertinoIcons.music_note, isDark),
            _buildPlatformChip(SocialPlatform.youtube, 'Shorts', CupertinoIcons.play_rectangle, isDark),
            _buildPlatformChip(SocialPlatform.facebook, 'Facebook', CupertinoIcons.bubble_left_bubble_right, isDark),
          ],
        ),

        // Instagram Layout Mode (Reel vs Feed)
        if (_selectedPlatform == SocialPlatform.instagram) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Layout: ',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(width: 8),
              CupertinoSlidingSegmentedControl<bool>(
                groupValue: _isReelMode,
                children: const {
                  true: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Reels (9:16)', style: TextStyle(fontSize: 11))),
                  false: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Feed (1:1)', style: TextStyle(fontSize: 11))),
                },
                onValueChanged: (val) {
                  if (val != null) setState(() => _isReelMode = val);
                },
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Media Testing Controls Card with Custom Upload
        Text(
          'ACTIVE MEDIA & TESTING',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        AppleGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isVideo ? AppleTheme.systemPurple : AppleTheme.systemTeal).withAlpha(35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.photo_fill,
                      color: isVideo ? AppleTheme.systemPurple : AppleTheme.systemTeal,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mediaUrl.split('/').last,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isVideo ? 'MP4 Video Reel' : 'Graphic Photo Asset',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final res = await MediaPickerDialog.show(context);
                  if (res != null) {
                    setState(() {
                      _customMediaUrl = res.pathOrUrl;
                      _customIsVideo = res.isVideo;
                    });
                  }
                },
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppleTheme.systemBlue, Color(0xFF0056B3)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppleTheme.systemBlue.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.folder_badge_plus, size: 15, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Upload / Swap Media',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Queue Post Selector
        Text(
          'SELECT QUEUE POST TO PREVIEW',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final post = posts[index];
            final isSelected = post.id == activePost.id;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedPostId = post.id;
                  _selectedPlatform = post.primaryPlatform;
                  _customMediaUrl = null;
                  _customIsVideo = null;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppleTheme.systemBlue.withAlpha(isDark ? 45 : 25)
                      : (isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppleTheme.systemBlue
                        : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8)),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 44,
                        height: 44,
                        color: Colors.black26,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              post.mediaUrl.startsWith('assets/') ? post.mediaUrl : 'assets/samples/emms_post1_story30mins.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(CupertinoIcons.photo, size: 20, color: Colors.white54),
                            ),
                            if (post.isVideo)
                              const Center(
                                child: Icon(CupertinoIcons.play_circle_fill, size: 18, color: Colors.white),
                              ),
                          ],
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
                                  color: post.platformInfo.color.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  post.platformInfo.name,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: post.platformInfo.color,
                                  ),
                                ),
                              ),
                              if (post.isVideo) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppleTheme.systemPurple.withAlpha(30),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'VIDEO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppleTheme.systemPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            post.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? Colors.white : AppleTheme.systemBlue)
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Right Inspector Column
  Widget _buildInspectorColumn(PostModel activePost, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Creator Studio Inspector',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Virality metrics, dispatch diagnostics & caption export.',
          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
        ),

        const SizedBox(height: 18),

        // Virality Score Card
        AppleGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STORY HOOK VELOCITY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppleTheme.systemGreen.withAlpha(35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'VIRAL GRADE',
                      style: TextStyle(color: AppleTheme.systemGreen, fontSize: 9.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '94',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppleTheme.systemGreen,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/100',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38),
                  ),
                  const Spacer(),
                  const Icon(CupertinoIcons.flame_fill, color: AppleTheme.systemOrange, size: 22),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.94,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(AppleTheme.systemGreen),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Hooks viewers within 2.8 seconds. Emotional bridge from tension to solution verified.',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Recommended Window Card
        AppleGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.clock_fill, color: AppleTheme.systemBlue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'OPTIMAL PUBLISHING WINDOW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '6:30 PM EAT (Nairobi Prime)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'East Africa peak engagement window for founder storytelling reels.',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Caption Diagnostics Card
        AppleGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CAPTION INSPECTOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  Text(
                    '${activePost.caption.length} / 2,200',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  activePost.caption,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: activePost.caption));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Caption and tags copied to clipboard!')),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.doc_on_clipboard, size: 14, color: isDark ? Colors.white : Colors.black87),
                    const SizedBox(width: 6),
                    Text(
                      'Copy Caption',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Primary Action: Publish Now via Daemon
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(vertical: 12),
          borderRadius: BorderRadius.circular(12),
          onPressed: () {
            context.read<PostsProvider>().publishNow(activePost.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dispatched "${activePost.title}" to ${activePost.platformInfo.name} via Daemon!')),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.paperplane_fill, size: 14),
              const SizedBox(width: 8),
              Text(
                'Publish Now to ${activePost.platformInfo.name}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformChip(SocialPlatform platform, String label, IconData icon, bool isDark) {
    final isSelected = _selectedPlatform == platform;
    final color = PlatformInfo.fromPlatform(platform).color;

    return InkWell(
      onTap: () => setState(() => _selectedPlatform = platform),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? color.withAlpha(50) : color.withAlpha(25))
              : (isDark ? Colors.white.withAlpha(12) : Colors.black.withAlpha(8)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(12)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : (isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? (isDark ? Colors.white : color) : (isDark ? Colors.white70 : Colors.black87),
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

  // 1. INSTAGRAM REEL (Zero-overflow hardened)
  Widget _buildInstagramReel(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
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

        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withAlpha(110),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withAlpha(200),
                ],
                stops: const [0.0, 0.16, 0.55, 1.0],
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
            children: const [
              Text(
                'Reels',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              Icon(CupertinoIcons.camera, color: Colors.white, size: 24),
            ],
          ),
        ),

        // Right Action Bar
        Positioned(
          right: 14,
          bottom: 75,
          child: Column(
            children: [
              _buildMetricIcon(CupertinoIcons.heart_fill, post.likesCount > 0 ? post.likes : "2.8K", Colors.redAccent),
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

        // Bottom Info (Hardened with Flexible & Expanded: ZERO OVERFLOW)
        Positioned(
          left: 16,
          right: 80,
          bottom: 42,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundImage: AssetImage('assets/emms_avatar.png'),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        handle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withAlpha(150), width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Follow', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(CupertinoIcons.music_note, color: Colors.white, size: 12),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Original audio - $authorName',
                        style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. INSTAGRAM FEED (Zero-overflow hardened)
  Widget _buildInstagramFeed(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          const SizedBox(height: 48),
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
                      Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                      Text(handle, style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 10.5), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.ellipsis, color: Colors.white, size: 16),
              ],
            ),
          ),
          Expanded(
            child: UniversalMediaPlayer(
              mediaUrl: mediaUrl,
              isVideo: isVideo,
              fit: BoxFit.cover,
              autoPlay: true,
              showControls: true,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: const [
                Icon(CupertinoIcons.heart, color: Colors.white, size: 22),
                SizedBox(width: 16),
                Icon(CupertinoIcons.bubble_left, color: Colors.white, size: 20),
                SizedBox(width: 16),
                Icon(CupertinoIcons.paperplane, color: Colors.white, size: 20),
                Spacer(),
                Icon(CupertinoIcons.bookmark, color: Colors.white, size: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
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

  // 3. TIKTOK (Zero-overflow hardened)
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
              _buildMetricIcon(CupertinoIcons.heart_fill, post.likesCount > 0 ? post.likes : "12.4K", Colors.white),
              const SizedBox(height: 16),
              _buildMetricIcon(CupertinoIcons.bubble_left_fill, '${post.comments > 0 ? post.comments : "389"}', Colors.white),
              const SizedBox(height: 16),
              _buildMetricIcon(CupertinoIcons.bookmark_fill, '1.2K', Colors.white),
              const SizedBox(height: 16),
              _buildMetricIcon(CupertinoIcons.arrowshape_turn_up_right_fill, 'Share', Colors.white),
              const SizedBox(height: 18),
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
        Positioned(
          left: 14,
          right: 76,
          bottom: 30,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(handle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(
                post.caption,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(CupertinoIcons.music_note_2, size: 12, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Trending Story Sound - $authorName',
                      style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. YOUTUBE SHORTS (Zero-overflow hardened)
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
        Positioned(
          right: 12,
          bottom: 60,
          child: Column(
            children: [
              _buildMetricIcon(CupertinoIcons.hand_thumbsup_fill, post.likesCount > 0 ? post.likes : "3.1K", Colors.white),
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
                  Flexible(
                    child: Text(
                      authorName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
                    child: const Text('Subscribe', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
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

  // 5. FACEBOOK POST (Zero-overflow hardened)
  Widget _buildFacebookPost(PostModel post, String mediaUrl, bool isVideo, String authorName, String handle) {
    return Container(
      color: const Color(0xFF18191A),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const CircleAvatar(radius: 18, backgroundImage: AssetImage('assets/emms_avatar.png')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Text('Just now • ', style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 11)),
                          const Icon(CupertinoIcons.globe, color: Colors.white54, size: 11),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(CupertinoIcons.ellipsis, color: Colors.white70, size: 18),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                post.caption,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            child: UniversalMediaPlayer(
              mediaUrl: mediaUrl,
              isVideo: isVideo,
              fit: BoxFit.cover,
              autoPlay: true,
              showControls: true,
            ),
          ),
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFbButton(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600)),
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
