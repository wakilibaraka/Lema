import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../models/script_model.dart';
import '../providers/posts_provider.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/dynamic_capsule.dart';
import '../widgets/media_player_widget.dart';

class HooksPipelineView extends StatefulWidget {
  const HooksPipelineView({super.key});

  @override
  State<HooksPipelineView> createState() => _HooksPipelineViewState();
}

class _HooksPipelineViewState extends State<HooksPipelineView> {
  final List<ScriptModel> _scripts = [
    ScriptModel(
      id: 'h1',
      title: 'Stop Blending In: The 3-Second Rule',
      hook: 'Stop blending in. If your video doesn’t hook someone in 3 seconds, they are gone.',
      problem: 'Most business owners start by introducing themselves. Nobody cares yet.',
      solution: 'Start with the specific pain point your client felt this morning.',
      cta: 'DM me "STORY" or call 0757 638 846 to fix your reels.',
      mediaAsset: 'assets/samples/emms_storytelling_reel.mp4',
      stage: ScriptStage.readyToRecord,
    ),
    ScriptModel(
      id: 'h2',
      title: 'Selling Feelings vs Selling Product',
      hook: 'People don’t buy your camera resolution or your software features. They buy how it makes them feel.',
      problem: 'Listing features triggers rational skepticism and comparison shopping.',
      solution: 'Paint the picture of relief, pride, and authority after their problem is solved.',
      cta: 'Contact Emms Digital Media to craft stories that actually convert.',
      mediaAsset: 'assets/samples/emms_story_features.mp4',
      stage: ScriptStage.recorded,
    ),
    ScriptModel(
      id: 'h3',
      title: 'The 30-Minute Case Study Framework',
      hook: 'How to turn a satisfied customer into a 30-second client-magnet video.',
      problem: 'Asking clients for testimonials produces boring, generic praise.',
      solution: 'Ask them: Where were you before? What was the breaking point? How is life today?',
      cta: 'Save this reel for your next client interview.',
      mediaAsset: 'assets/samples/emms_post1_story30mins.png',
      stage: ScriptStage.published,
    ),
    ScriptModel(
      id: 'h4',
      title: 'The One-Sentence Transformation Pitch',
      hook: 'If you can’t describe your business value in one sentence, your clients can’t either.',
      problem: 'Over-explaining creates friction and kills sales momentum.',
      solution: 'Use this formula: We help [Target Audience] achieve [Dream Result] without [Painful Obstacle].',
      cta: 'Drop your one-sentence pitch in the comments and I will critique it.',
      mediaAsset: 'assets/samples/emms_post3_onesentence.png',
      stage: ScriptStage.draft,
    ),
  ];

  ScriptModel? _activeScript;

  @override
  void initState() {
    super.initState();
    _activeScript = _scripts.first;
  }

  void _pushToQueue(ScriptModel script) {
    final caption = '${script.hook}\n\n${script.problem}\n\n${script.solution}\n\n🎬 ${script.cta}';
    final isVid = script.mediaAsset.endsWith('.mp4');

    final post = PostModel(
      id: 'script_${DateTime.now().millisecondsSinceEpoch}',
      caption: caption,
      scheduledTime: DateTime.now().add(const Duration(hours: 5)),
      platform: SocialPlatform.instagram,
      mediaUrl: script.mediaAsset,
      isVideo: isVid,
    );

    context.read<PostsProvider>().addPost(post);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Transferred "${script.title}" into Publishing Queue!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      'Hooks & Video Scripts Pipeline',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'High-converting 60-second storytelling scripts engineered for viral client acquisition.',
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

            // Master-Detail Layout
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Scripts List
                  Expanded(
                    flex: 4,
                    child: ListView.separated(
                      itemCount: _scripts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final script = _scripts[index];
                        final isSelected = script.id == _activeScript?.id;

                        return AppleGlassCard(
                          padding: const EdgeInsets.all(14),
                          customBorder: isSelected
                              ? Border.all(color: AppleTheme.systemBlue, width: 1.5)
                              : null,
                          onTap: () => setState(() => _activeScript = script),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStageColor(script.stage).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      script.stageName,
                                      style: TextStyle(
                                        color: _getStageColor(script.stage),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    script.mediaAsset.endsWith('.mp4') ? CupertinoIcons.videocam_fill : CupertinoIcons.photo_fill,
                                    size: 14,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                script.title,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                script.hook,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Detail & Teleprompter Card
                  Expanded(
                    flex: 6,
                    child: _activeScript == null
                        ? const Center(child: Text('Select a script'))
                        : AppleGlassCard(
                            padding: const EdgeInsets.all(22),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Detail Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _activeScript!.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                      CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        color: AppleTheme.systemBlue,
                                        borderRadius: BorderRadius.circular(10),
                                        onPressed: () => _pushToQueue(_activeScript!),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.arrow_right_circle_fill, size: 14),
                                            SizedBox(width: 6),
                                            Text('Send to Queue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Divider(height: 24),

                                  // Teleprompter Script Blocks
                                  _buildScriptSection('1. 3-SECOND HOOK (STOP SCROLL)', _activeScript!.hook, AppleTheme.systemRed, isDark),
                                  const SizedBox(height: 14),
                                  _buildScriptSection('2. THE CORE PROBLEM (RELATABLE PAIN)', _activeScript!.problem, AppleTheme.systemOrange, isDark),
                                  const SizedBox(height: 14),
                                  _buildScriptSection('3. TRANSFORMATION & FRAMEWORK', _activeScript!.solution, AppleTheme.systemGreen, isDark),
                                  const SizedBox(height: 14),
                                  _buildScriptSection('4. CALL TO ACTION (CTA)', _activeScript!.cta, AppleTheme.systemBlue, isDark),

                                  const SizedBox(height: 20),

                                  // Attached Reel Preview
                                  Text(
                                    'ATTACHED PRODUCTION MEDIA',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: isDark ? Colors.white38 : Colors.black38),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      height: 180,
                                      child: UniversalMediaPlayer(
                                        mediaUrl: _activeScript!.mediaAsset,
                                        isVideo: _activeScript!.mediaAsset.endsWith('.mp4'),
                                        autoPlay: false,
                                        showControls: true,
                                      ),
                                    ),
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
      ),
    );
  }

  Widget _buildScriptSection(String label, String content, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.5),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 14),
                color: isDark ? Colors.white38 : Colors.black38,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied section to clipboard!')));
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            content,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStageColor(ScriptStage stage) {
    switch (stage) {
      case ScriptStage.draft:
        return AppleTheme.systemOrange;
      case ScriptStage.readyToRecord:
        return AppleTheme.systemBlue;
      case ScriptStage.recorded:
        return AppleTheme.systemPurple;
      case ScriptStage.published:
        return AppleTheme.systemGreen;
    }
  }
}
