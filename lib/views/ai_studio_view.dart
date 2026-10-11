import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../models/profile_model.dart';
import '../providers/posts_provider.dart';
import '../providers/profile_provider.dart';
import '../services/ai_service.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';

class AiStudioView extends StatefulWidget {
  const AiStudioView({super.key});

  @override
  State<AiStudioView> createState() => _AiStudioViewState();
}

class _AiStudioViewState extends State<AiStudioView> {
  final TextEditingController _promptController = TextEditingController();
  SocialPlatform _platform = SocialPlatform.instagram;
  String _selectedTone = 'Storytelling & Emotional';
  bool _isLoading = false;
  String? _generatedContent;
  List<Map<String, dynamic>>? _generatedBatch;

  /// Slice 19: failures render as an in-place error card with Retry instead
  /// of a transient snackbar, so the studio degrades gracefully offline.
  String? _error;
  Future<void> Function()? _lastAction;

  final List<String> _tones = [
    'Storytelling & Emotional',
    'Direct & Value-First',
    'Educational Masterclass',
    'Behind-the-Scenes & Raw',
    'Contrarian & Provocative',
  ];

  @override
  void initState() {
    super.initState();
    _promptController.text = 'Why 90% of business videos get ignored and how storytelling fixes it';
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generatePost() async {
    final profile = context.read<ProfileProvider>().activeProfile;

    setState(() {
      _isLoading = true;
      _generatedContent = null;
      _generatedBatch = null;
      _error = null;
      _lastAction = _generatePost;
    });

    try {
      final result = await AiService.generateSinglePost(
        prompt: _promptController.text.trim(),
        profile: profile,
        platform: _platform.name,
      );

      if (!mounted) return;
      setState(() {
        _generatedContent = result;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generate7DayPlan() async {
    final profile = context.read<ProfileProvider>().activeProfile;

    setState(() {
      _isLoading = true;
      _generatedContent = null;
      _generatedBatch = null;
      _error = null;
      _lastAction = _generate7DayPlan;
    });

    try {
      final batch = await AiService.generate7DayContentPlan(
        focusTopic: _promptController.text.trim().isNotEmpty
            ? _promptController.text.trim()
            : 'Storytelling Reels for High-Ticket Client Acquisition',
        profile: profile,
      );

      if (!mounted) return;
      setState(() {
        _generatedBatch = batch;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addGeneratedToQueue(String caption, {String? mediaUrl, bool isVideo = true}) {
    final newPost = PostModel(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      caption: caption,
      scheduledTime: DateTime.now().add(const Duration(hours: 4)),
      platform: _platform,
      mediaUrl: mediaUrl ?? 'assets/samples/emms_storytelling_reel.mp4',
      isVideo: isVideo,
    );

    context.read<PostsProvider>().addPost(newPost);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added AI Generated Post to Publishing Queue!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = context.watch<ProfileProvider>().activeProfile;
    // Slice 19: phones (< 700pt, same breakpoint as Calendar) stack the
    // controls above the output in one scroll; desktop keeps side-by-side.
    final isNarrow = MediaQuery.of(context).size.width < 700;

    if (isNarrow) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPageHeader(isDark, compact: true),
              const SizedBox(height: 16),
              _buildControls(isDark, profile, compact: true),
              const SizedBox(height: 16),
              _buildOutputCard(isDark, fixedHeight: true),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPageHeader(isDark, compact: false),

            const SizedBox(height: 20),

            // Main Editor & Output Split
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: Persona & Generation Controls
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: _buildControls(isDark, profile, compact: false),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right: Output Area
                  Expanded(
                    flex: 6,
                    child: _buildOutputCard(isDark, fixedHeight: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Slice 19: page header shared by both layouts. The compact variant uses
  /// the short product title so it fits 402pt; both carry product copy
  /// instead of the old ported-engine subtitle (§4 AI Studio copy).
  Widget _buildPageHeader(bool isDark, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI STUDIO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          compact ? 'AI Studio' : 'AI Studio & Content Planner',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Describe a topic and get scroll-stopping captions, hooks and a full 7-day plan — tuned to your voice.',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  /// Slice 19: generation controls shared by both layouts. Compact stacks
  /// the two generate actions full-width (they overflow side-by-side at
  /// 402pt); desktop keeps them side by side.
  Widget _buildControls(bool isDark, ProfileModel profile,
      {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Active Persona Summary
        AppleGlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(isDark, profile),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Persona: ${profile.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target Audience: African businesses, brand owners & agencies',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppleTheme.systemPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('GEMINI 1.5 PRO', style: TextStyle(color: AppleTheme.systemPurple, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Target Platform selection
        Text(
          'TARGET NETWORK',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(height: 8),
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

        // Tone Selection
        Text(
          'TONE OF VOICE',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _tones.map((t) {
            final isSel = _selectedTone == t;
            return ChoiceChip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
              selected: isSel,
              selectedColor: AppleTheme.systemBlue,
              onSelected: (sel) {
                if (sel) setState(() => _selectedTone = t);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Prompt Input
        Text(
          'TOPIC / HOOK CONCEPT',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _promptController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe your topic, hook idea, or campaign goal...',
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Action Buttons
        if (compact) ...[
          _generatePostButton(isDark),
          const SizedBox(height: 10),
          _generatePlanButton(isDark),
        ] else
          Row(
            children: [
              Expanded(child: _generatePostButton(isDark)),
              const SizedBox(width: 12),
              Expanded(child: _generatePlanButton(isDark)),
            ],
          ),
      ],
    );
  }

  Widget _generatePostButton(bool isDark) {
    return CupertinoButton.filled(
      padding: const EdgeInsets.symmetric(vertical: 14),
      borderRadius: BorderRadius.circular(12),
      onPressed: _isLoading ? null : _generatePost,
      child: _isLoading
          ? const CupertinoActivityIndicator(color: Colors.white)
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.sparkles, size: 16),
                SizedBox(width: 8),
                Flexible(
                  child: Text('Generate Single Post',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ),
    );
  }

  Widget _generatePlanButton(bool isDark) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 14),
      color: AppleTheme.systemPurple,
      borderRadius: BorderRadius.circular(12),
      onPressed: _isLoading ? null : _generate7DayPlan,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.calendar_badge_plus,
              size: 16, color: Colors.white),
          SizedBox(width: 8),
          Flexible(
            child: Text('Generate 7-Day Plan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Slice 19: persona avatar with an initials fallback so a missing bundled
  /// asset degrades to a monogram instead of an error box.
  Widget _buildAvatar(bool isDark, ProfileModel profile) {
    final initial =
        profile.name.isNotEmpty ? profile.name.characters.first : 'E';
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.asset(
          'assets/emms_avatar.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppleTheme.systemPurple.withValues(alpha: 0.2),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppleTheme.systemPurple,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slice 19: output card shared by both layouts. On phones the body gets a
  /// fixed height so the empty/loading states center and batch lists scroll
  /// internally instead of overflowing.
  Widget _buildOutputCard(bool isDark, {required bool fixedHeight}) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'AI Output Preview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (_generatedContent != null)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: AppleTheme.systemBlue,
                borderRadius: BorderRadius.circular(8),
                onPressed: () => _addGeneratedToQueue(_generatedContent!),
                child: const Text('Add to Queue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const Divider(height: 20),
        fixedHeight
            ? SizedBox(height: 400, child: _buildOutputBody(isDark))
            : Expanded(
                child: _buildOutputBody(isDark),
              ),
      ],
    );

    return AppleGlassCard(
      padding: const EdgeInsets.all(20),
      child: body,
    );
  }

  Widget _buildOutputBody(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 16),
            SizedBox(height: 14),
            Text('Generating AI Content with Gemini...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      );
    }

    // Slice 19: failures render in place with Retry (graceful offline).
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle,
                size: 36, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 10),
            Text(
              'Generation hit a snag.',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 14),
            CupertinoButton.filled(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              borderRadius: BorderRadius.circular(12),
              onPressed: _lastAction == null
                  ? null
                  : () {
                      final action = _lastAction;
                      if (action != null) action();
                    },
              child: const Text('Retry',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    if (_generatedBatch != null && _generatedBatch!.isNotEmpty) {
      return ListView.separated(
        itemCount: _generatedBatch!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _generatedBatch![index];
          final day = item['day'] ?? 'Day ${index + 1}';
          final hook = item['hook'] ?? '';
          final caption = item['caption'] ?? '';
          final media = item['media'] ?? 'assets/samples/emms_storytelling_reel.mp4';
          final isVideo = item['isVideo'] ?? true;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppleTheme.systemPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        day,
                        style: const TextStyle(color: AppleTheme.systemPurple, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _addGeneratedToQueue(caption, mediaUrl: media, isVideo: isVideo),
                      child: const Text('Queue This Post', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hook,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, height: 1.3),
                ),
              ],
            ),
          );
        },
      );
    }

    if (_generatedContent != null) {
      return SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            _generatedContent!,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.sparkles, size: 40, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 10),
          Text(
            'Tap "Generate Single Post" or "Generate 7-Day Plan" to begin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }
}
