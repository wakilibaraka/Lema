import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nav_destination.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../providers/app_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/error_banner.dart';
import '../widgets/media_picker_dialog.dart';
import '../widgets/media_player_widget.dart';
import '../widgets/schedule_time_picker.dart';

class ComposerView extends StatefulWidget {
  const ComposerView({super.key});

  @override
  State<ComposerView> createState() => _ComposerViewState();
}

class _ComposerViewState extends State<ComposerView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _coreController = TextEditingController();
  final Map<String, TextEditingController> _platformOverrides = {};
  final Map<String, String> _platformMediaUrls = {};
  final Map<String, bool> _platformIsVideo = {};
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 3));

  static const Map<String, int> _charLimits = {
    'instagram': 2200,
    'tiktok': 2200,
    'youtube': 5000,
    'facebook': 63206,
    'linkedin': 3000,
    'twitter': 280,
  };

  static const Map<String, String> _platformTips = {
    'instagram': 'Links in captions are not clickable. Use link in bio.',
    'tiktok': 'Keep it punchy. Use trending hashtags.',
    'youtube': 'Title required. Description supports timestamps.',
    'facebook': 'Longer posts perform well. Ask questions.',
    'linkedin': 'Professional tone. Line breaks improve readability.',
    'twitter': 'Concise and punchy. Thread for longer content.',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SocialPlatform.values.length,
      vsync: this,
    );
    for (final p in SocialPlatform.values) {
      _platformOverrides[p.name] = TextEditingController();
    }
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _coreController.dispose();
    for (final c in _platformOverrides.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _effectiveCaption(String platform) {
    final override = _platformOverrides[platform]?.text ?? '';
    return override.isNotEmpty ? override : _coreController.text;
  }

  int _charCount(String platform) => _effectiveCaption(platform).length;

  int _charLimit(String platform) => _charLimits[platform] ?? 2200;

  bool _isOverLimit(String platform) =>
      _charCount(platform) > _charLimit(platform);

  List<String> get _selectedPlatforms {
    return SocialPlatform.values
        .where((p) => _platformMediaUrls.containsKey(p.name))
        .map((p) => p.name)
        .toList();
  }

  /// [asDraft] is what the "Save as Draft" button passes. Both buttons used
  /// to call this unparameterised, so the draft button scheduled the post.
  void _schedulePost({bool asDraft = false}) {
    final caption = _coreController.text.trim();
    if (caption.isEmpty) return;

    final platforms = _selectedPlatforms.isEmpty
        ? [SocialPlatform.values[_tabController.index].name]
        : _selectedPlatforms;

    for (final platform in platforms) {
      final platformCaption = _effectiveCaption(platform);
      if (platformCaption.trim().isEmpty) continue;

      final post = PostModel(
        id: 'composer_${DateTime.now().millisecondsSinceEpoch}_$platform',
        caption: platformCaption,
        platforms: [platform],
        mediaUrl: _platformMediaUrls[platform] ?? '',
        isVideo: _platformIsVideo[platform] ?? false,
        scheduledTime: _scheduledTime,
        status: asDraft ? 'draft' : 'scheduled',
      );

      context.read<PostsProvider>().addPost(post);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          asDraft
              ? 'Saved as draft'
              : 'Scheduled for ${formatScheduleSlot(_scheduledTime)}',
        ),
      ),
    );

    _coreController.clear();
    for (final c in _platformOverrides.values) {
      c.clear();
    }
    setState(() {
      _platformMediaUrls.clear();
      _platformIsVideo.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Scrollable: the composer card stack is taller than a 600pt-tall
      // window, which overflowed by 120px. The 140pt bottom inset also
      // keeps the action row clear of the docked glass tab bar
      // (the shell runs with extendBody: true).
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
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
                        'Composer',
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
                        'Write once, format per platform.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (auth.hasAnyExpired)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ErrorBanner.tokenExpiredBanner(
                  platform: auth.expiredPlatforms.first,
                  // Reconnect lives in Settings (Connected Accounts); the
                  // banner used to be a dead end with an empty callback.
                  onReconnect: () => context.read<AppProvider>().setNavIndex(
                    settingsDestinationIndex,
                  ),
                ),
              ),

            AppleGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPlatformTabs(isDark),
                  const SizedBox(height: 16),
                  _buildCoreComposer(isDark),
                  const SizedBox(height: 12),
                  _buildPlatformOverride(isDark),
                  const SizedBox(height: 12),
                  _buildMediaSection(isDark),
                  const SizedBox(height: 12),
                  _buildScheduleSection(isDark),
                  const SizedBox(height: 16),
                  _buildActionButtons(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformTabs(bool isDark) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SocialPlatform.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final platform = SocialPlatform.values[index];
          final info = PlatformInfo.fromPlatform(platform);
          final isSelected = _tabController.index == index;
          final isConnected = context.watch<AuthProvider>().isConnected(
            platform.name,
          );

          return GestureDetector(
            onTap: () => _tabController.animateTo(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? info.color.withAlpha(30)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? info.color : Colors.grey.withAlpha(60),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    info.iconData,
                    size: 14,
                    color: isSelected ? info.color : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    info.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? info.color : Colors.grey,
                    ),
                  ),
                  if (!isConnected) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppleTheme.systemRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoreComposer(bool isDark) {
    final platform = SocialPlatform.values[_tabController.index].name;
    final count = _charCount(platform);
    final limit = _charLimit(platform);
    final overLimit = _isOverLimit(platform);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _coreController,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Write your core message...',
            filled: true,
            fillColor: isDark
                ? Colors.white.withAlpha(12)
                : Colors.black.withAlpha(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Flexible: with spaceBetween and an unbounded tip string, the
            // counter was pushed 44px past the right edge at tablet width.
            Flexible(
              child: Text(
                _platformTips[platform] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count / $limit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: overLimit
                    ? AppleTheme.systemRed
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlatformOverride(bool isDark) {
    final platform = SocialPlatform.values[_tabController.index].name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Override for ${PlatformInfo.fromString(platform).name} (optional)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _platformOverrides[platform],
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Leave empty to use core message...',
            filled: true,
            fillColor: isDark
                ? Colors.white.withAlpha(8)
                : Colors.black.withAlpha(5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection(bool isDark) {
    final platform = SocialPlatform.values[_tabController.index].name;
    final mediaUrl = _platformMediaUrls[platform] ?? '';
    final isVideo = _platformIsVideo[platform] ?? false;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: mediaUrl.isNotEmpty
                ? UniversalMediaPlayer(
                    mediaUrl: mediaUrl,
                    isVideo: isVideo,
                    autoPlay: false,
                    showControls: false,
                    thumbnail: true,
                  )
                : Container(
                    color: isDark ? Colors.white12 : Colors.black12,
                    child: Icon(
                      CupertinoIcons.photo,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mediaUrl.isNotEmpty
                ? mediaUrl.split('/').last
                : 'No media attached',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
          onPressed: () async {
            final res = await MediaPickerDialog.show(context);
            if (res != null) {
              setState(() {
                _platformMediaUrls[platform] = res.pathOrUrl;
                _platformIsVideo[platform] = res.isVideo;
              });
            }
          },
          child: Text(
            'Attach',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSection(bool isDark) {
    return Row(
      children: [
        Icon(
          CupertinoIcons.clock,
          size: 14,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 8),
        Text(
          'Schedule: ${formatScheduleSlot(_scheduledTime)}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const Spacer(),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          onPressed: () async {
            // Date *and* time: the old picker only chose a day, so every post
            // from this screen kept the "now + 3h" clock it booted with.
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
            style: TextStyle(fontSize: 11, color: AppleTheme.systemBlue),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(10),
            borderRadius: BorderRadius.circular(12),
            onPressed: () => _schedulePost(asDraft: true),
            child: Text(
              'Save as Draft',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(vertical: 12),
            borderRadius: BorderRadius.circular(12),
            onPressed: _schedulePost,
            child: const Text(
              'Schedule Post',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
