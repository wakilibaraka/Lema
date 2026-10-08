import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../providers/posts_provider.dart';
import '../providers/profile_provider.dart';
import '../services/ai_service.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/dynamic_capsule.dart';

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
    if (profile == null) return;

    setState(() {
      _isLoading = true;
      _generatedContent = null;
      _generatedBatch = null;
    });

    try {
      final result = await AiService.generateSinglePost(
        prompt: _promptController.text.trim(),
        profile: profile,
        platform: _platform.name,
      );

      setState(() {
        _generatedContent = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generation error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generate7DayPlan() async {
    final profile = context.read<ProfileProvider>().activeProfile;
    if (profile == null) return;

    setState(() {
      _isLoading = true;
      _generatedContent = null;
      _generatedBatch = null;
    });

    try {
      final batch = await AiService.generate7DayContentPlan(
        focusTopic: _promptController.text.trim().isNotEmpty
            ? _promptController.text.trim()
            : 'Storytelling Reels for High-Ticket Client Acquisition',
        profile: profile,
      );

      setState(() {
        _generatedBatch = batch;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Plan generation error: $e')));
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
                      'AI Studio & Content Planner',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ported from Content_AI engine with Gemini LLM & Persona-driven generation.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const DynamicCapsule(),
              ],
            ),

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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Active Persona Summary
                          AppleGlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 20,
                                  backgroundImage: AssetImage('assets/emms_avatar.png'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'AI Persona: ${profile?.name ?? "The Content Doctor"}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Target Audience: African businesses, brand owners & agencies',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppleTheme.systemPurple.withOpacity(0.15),
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
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton.filled(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: _isLoading ? null : _generatePost,
                                  child: _isLoading
                                      ? const CupertinoActivityIndicator(color: Colors.white)
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(CupertinoIcons.sparkles, size: 16),
                                            SizedBox(width: 8),
                                            Text('Generate Single Post', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  color: AppleTheme.systemPurple,
                                  borderRadius: BorderRadius.circular(12),
                                  onPressed: _isLoading ? null : _generate7DayPlan,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.calendar_badge_plus, size: 16, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Generate 7-Day Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right: Output Area
                  Expanded(
                    flex: 6,
                    child: AppleGlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'AI Output Preview',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
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
                          Expanded(
                            child: _buildOutputBody(isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    if (_generatedBatch != null && _generatedBatch!.isNotEmpty) {
      return ListView.separated(
        itemCount: _generatedBatch!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
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
                        color: AppleTheme.systemPurple.withOpacity(0.15),
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
            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
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
            'Click "Generate Single Post" or "Generate 7-Day Plan" to begin.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
          ),
        ],
      ),
    );
  }
}
