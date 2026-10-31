import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/platform_info.dart';
import '../models/post_model.dart';
import '../models/script_model.dart';
import '../providers/posts_provider.dart';
import '../theme/backdrop_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/media_player_widget.dart';
import '../services/storage_service.dart';

class HooksPipelineView extends StatefulWidget {
  const HooksPipelineView({super.key});

  @override
  State<HooksPipelineView> createState() => _HooksPipelineViewState();
}

class _HooksPipelineViewState extends State<HooksPipelineView> {
  final List<ScriptModel> _scripts = StorageService.instance.loadScripts();

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
    ScaffoldMessenger.of(context).showSnackBar(            SnackBar(content: Text('Transferred "${script.title}" into the Queue!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Slice 21: phones (< 700pt, same breakpoint as Calendar/AI Studio)
    // stack full-width script cards; tapping one opens the detail sheet.
    // Desktop keeps the master-detail split. Both share the same builders.
    final isNarrow = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPageHeader(isDark, compact: isNarrow),

            const SizedBox(height: 20),

            if (isNarrow)
              Expanded(
                child: ListView.separated(
                  itemCount: _scripts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final script = _scripts[index];
                    return _scriptCard(
                      script,
                      isDark,
                      selected: script.id == _activeScript?.id,
                      onTap: () {
                        setState(() => _activeScript = script);
                        _openDetailSheet(context, script, isDark);
                      },
                    );
                  },
                ),
              )
            else
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
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final script = _scripts[index];
                          final isSelected = script.id == _activeScript?.id;

                          return _scriptCard(
                            script,
                            isDark,
                            selected: isSelected,
                            onTap: () =>
                                setState(() => _activeScript = script),
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
                          : _scriptDetail(_activeScript!, isDark),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Slice 21: page header shared by both layouts. The destination is named
  /// "Hooks" everywhere now, so the header matches the sidebar, title bar and
  /// dock instead of inventing "Hooks & Video Scripts Pipeline".
  Widget _buildPageHeader(bool isDark, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOOKS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Hooks',
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
          'High-converting 60-second storytelling scripts engineered for viral client acquisition.',
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

  /// Slice 21: script card shared by the mobile list and the desktop pane.
  /// All type is clamped so narrow columns degrade with ellipsis, never
  /// with overflow stripes.
  Widget _scriptCard(
    ScriptModel script,
    bool isDark, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return AppleGlassCard(
      padding: const EdgeInsets.all(14),
      customBorder: selected
          ? Border.all(color: BackdropTheme.accent, width: 1.5)
          : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStageColor(script.stage).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    script.stageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _getStageColor(script.stage),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
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
  }

  /// Slice 21: detail + teleprompter, shared by the desktop pane and the
  /// mobile bottom sheet.
  Widget _scriptDetail(ScriptModel script, bool isDark) {
    return AppleGlassCard(
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
                    script.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: BackdropTheme.accent,
                  // Plain CupertinoButton defaults its foreground to the
                  // same #007AFF as this background; set it explicitly.
                  foregroundColor: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  onPressed: () => _pushToQueue(script),
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
            _buildScriptSection('1. 3-SECOND HOOK (STOP SCROLL)', script.hook, BackdropTheme.statusWarning, isDark),
            const SizedBox(height: 14),
            _buildScriptSection('2. THE CORE PROBLEM (RELATABLE PAIN)', script.problem, BackdropTheme.statusWarning, isDark),
            const SizedBox(height: 14),
            _buildScriptSection('3. TRANSFORMATION & FRAMEWORK', script.solution, BackdropTheme.statusOnline, isDark),
            const SizedBox(height: 14),
            _buildScriptSection('4. CALL TO ACTION (CTA)', script.cta, BackdropTheme.accent, isDark),

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
                  mediaUrl: script.mediaAsset,
                  isVideo: script.mediaAsset.endsWith('.mp4'),
                  autoPlay: false,
                  showControls: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Slice 21: mobile detail opens as a bottom sheet (quick-edit pattern).
  void _openDetailSheet(BuildContext context, ScriptModel script, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C22) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: _scriptDetail(script, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScriptSection(String label, String content, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Slice 21: bounded so long section labels ellipsize instead
              // of striping at 402pt.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.5),
                ),
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
        return BackdropTheme.statusWarning;
      case ScriptStage.readyToRecord:
        return BackdropTheme.accent;
      case ScriptStage.recorded:
        return BackdropTheme.violet;
      case ScriptStage.published:
        return BackdropTheme.statusOnline;
    }
  }
}
