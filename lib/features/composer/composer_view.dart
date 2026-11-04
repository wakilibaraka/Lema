import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/destinations.dart';
import '../../core/models/platform_info.dart';
import '../../core/models/post_model.dart';
import '../../core/providers/app_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/posts_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/media_processing_service.dart';
import '../../core/theme.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/media_picker_dialog.dart';
import '../../widgets/media_player_widget.dart';
import '../../widgets/schedule_time_picker.dart';
import 'hashtag_field.dart';
import 'platform_preview.dart';

const double _splitWidth = 840;

/// Write once, pick platforms, adjust per platform. [inSheet] closes the
/// quick-draft sheet after saving.
class ComposerView extends StatefulWidget {
  final bool inSheet;

  const ComposerView({super.key, this.inSheet = false});

  @override
  State<ComposerView> createState() => _ComposerViewState();
}

class _ComposerViewState extends State<ComposerView> {
  final TextEditingController _caption = TextEditingController();
  final Map<String, TextEditingController> _overrides = {
    for (final p in SocialPlatform.values) p.name: TextEditingController(),
  };
  final Set<String> _selected = {SocialPlatform.instagram.name};
  String _active = SocialPlatform.instagram.name;
  String _mediaUrl = '';
  String _mediaName = '';
  bool _isVideo = false;
  int? _mediaSize;
  DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 3));
  String _recurrence = recurrenceNone;
  final Set<int> _days = {};
  bool _previewing = false;
  late final AppProvider _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppProvider>();
    // The sheet is a separate draft; vault picks go to the composer tab.
    if (!widget.inSheet) _app.addListener(_attachFromVault);
  }

  void _attachFromVault() {
    final asset = _app.takeAssetForComposer();
    if (asset == null) return;
    setState(() {
      _mediaUrl = asset.url;
      _mediaName = asset.name;
      _isVideo = asset.isVideo;
      _mediaSize = null;
    });
  }

  @override
  void dispose() {
    if (!widget.inSheet) _app.removeListener(_attachFromVault);
    _caption.dispose();
    for (final c in _overrides.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _captionFor(String platform) {
    final override = _overrides[platform]!.text;
    return override.isNotEmpty ? override : _caption.text;
  }

  /// A file name or path with an extension to check. Sample names have none,
  /// and an upload on web is a data URI, so use whichever carries it.
  String get _mediaFile {
    final source = _mediaUrl.startsWith('data:') ? _mediaName : _mediaUrl;
    return source.split('?').first.split('/').last;
  }

  List<String> _warningsFor(String platform) => [
        ...captionWarnings(platform, _captionFor(platform), hasMedia: _mediaUrl.isNotEmpty),
        if (_mediaFile.contains('.'))
          ...MediaProcessingService.validateMediaForAllPlatforms(
            filePath: _mediaFile,
            platforms: [platform],
            isVideo: _isVideo,
            fileSizeBytes: _mediaSize,
          ).map((i) => i.message),
      ];

  List<String> get _orderedSelection => [
        for (final p in SocialPlatform.values)
          if (_selected.contains(p.name)) p.name,
      ];

  void _toggle(String platform, bool on) => setState(() {
        on ? _selected.add(platform) : _selected.remove(platform);
        if (on) {
          _active = platform;
        } else if (_active == platform && _selected.isNotEmpty) {
          _active = _orderedSelection.first;
        }
      });

  void _addHashtag(String tag) {
    final text = _caption.text;
    final gap = text.isEmpty || text.endsWith(' ') || text.endsWith('\n') ? '' : ' ';
    setState(() => _caption.text = '$text$gap$tag');
  }

  void _save({bool asDraft = false}) {
    final posts = context.read<PostsProvider>();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (final platform in _orderedSelection) {
      final caption = _captionFor(platform).trim();
      if (caption.isEmpty) continue;
      posts.addPost(PostModel(
        id: 'composer_${stamp}_$platform',
        title: platform == SocialPlatform.youtube.name ? caption.split('\n').first : null,
        caption: caption,
        platforms: [platform],
        mediaUrl: _mediaUrl,
        isVideo: _isVideo,
        scheduledTime: _scheduledTime,
        status: asDraft ? 'draft' : 'scheduled',
        recurrence: _recurrence,
        recurrenceDays: _recurrence == recurrenceWeekly ? _days.toList() : const [],
      ));
    }

    final messenger = ScaffoldMessenger.of(context);
    if (widget.inSheet) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text(asDraft
          ? 'Saved as draft'
          : 'Scheduled for ${formatScheduleSlot(_scheduledTime)}'),
    ));
    if (widget.inSheet) return;

    _caption.clear();
    for (final c in _overrides.values) {
      c.clear();
    }
    setState(() {
      _mediaUrl = '';
      _mediaName = '';
      _mediaSize = null;
      _isVideo = false;
      _recurrence = recurrenceNone;
      _days.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final banner = auth.hasAnyExpired
              ? Padding(
                  padding: const EdgeInsets.only(bottom: LemaTheme.s3),
                  child: ErrorBanner.tokenExpiredBanner(
                    platforms: [
                      for (final p in auth.expiredPlatforms) platformsMap[p]?.name ?? p,
                    ],
                    onReconnect: () {
                      if (widget.inSheet) Navigator.of(context).pop();
                      context.read<AppProvider>().setNavIndex(settingsDestinationIndex);
                    },
                  ),
                )
              : const SizedBox.shrink();
          const pad = EdgeInsets.all(LemaTheme.s4);
          if (constraints.maxWidth >= _splitWidth) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: pad,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [banner, _editor()],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: SingleChildScrollView(padding: pad, child: _preview())),
              ],
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                LemaTheme.s4, LemaTheme.s4, LemaTheme.s4, LemaTheme.s8 * LemaTheme.s1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                banner,
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Edit')),
                      ButtonSegment(value: true, label: Text('Preview')),
                    ],
                    selected: {_previewing},
                    onSelectionChanged: (s) => setState(() => _previewing = s.first),
                  ),
                ),
                const SizedBox(height: LemaTheme.s4),
                _previewing ? _preview() : _editor(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _editor() {
    final scheme = Theme.of(context).colorScheme;
    final saved = context.watch<ProfileProvider>().activeProfile.defaultHashtags;
    final auth = context.watch<AuthProvider>();
    final selection = _orderedSelection;
    final warnings = [for (final p in selection) ..._warningsFor(p)];
    final canSave = selection.isNotEmpty && _caption.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: LemaTheme.s2,
          runSpacing: LemaTheme.s2,
          children: [
            for (final p in SocialPlatform.values)
              FilterChip(
                label: Text(platformsMap[p.name]!.name),
                selected: _selected.contains(p.name),
                tooltip: auth.isConnected(p.name) ? null : 'Not connected',
                onSelected: (on) => _toggle(p.name, on),
              ),
          ],
        ),
        const SizedBox(height: LemaTheme.s4),
        TextField(
          controller: _caption,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Write your post',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: LemaTheme.s2),
        Wrap(
          spacing: LemaTheme.s3,
          children: [
            for (final p in selection)
              Text(
                '${platformsMap[p]!.name} ${_captionFor(p).length} / ${platformRules[p]!.captionLimit}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: LemaTheme.s3),
        HashtagField(
          caption: _caption.text,
          selectedPlatforms: selection,
          saved: saved,
          onAdd: _addHashtag,
        ),
        const SizedBox(height: LemaTheme.s4),
        _mediaRow(),
        const SizedBox(height: LemaTheme.s3),
        for (final w in warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: LemaTheme.s1),
            child: Text(w, style: const TextStyle(fontSize: 12, color: LemaTheme.danger)),
          ),
        const SizedBox(height: LemaTheme.s2),
        _scheduleRow(),
        const SizedBox(height: LemaTheme.s2),
        _repeatPicker(),
        const SizedBox(height: LemaTheme.s4),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canSave ? () => _save(asDraft: true) : null,
                child: const Text('Save as Draft'),
              ),
            ),
            const SizedBox(width: LemaTheme.s3),
            Expanded(
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text('Schedule Post'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mediaRow() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(LemaTheme.radiusControl),
          child: Container(
            width: 48,
            height: 48,
            color: scheme.surfaceContainerHighest,
            child: _mediaUrl.isEmpty
                ? null
                : UniversalMediaPlayer(
                    mediaUrl: _mediaUrl,
                    isVideo: _isVideo,
                    autoPlay: false,
                    showControls: false,
                    thumbnail: true,
                  ),
          ),
        ),
        const SizedBox(width: LemaTheme.s3),
        Expanded(
          child: Text(
            _mediaUrl.isEmpty ? 'No media attached' : _mediaName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () async {
            final res = await MediaPickerDialog.show(context);
            if (res != null && mounted) {
              setState(() {
                _mediaUrl = res.pathOrUrl;
                _mediaName = res.name;
                _isVideo = res.isVideo;
                _mediaSize = res.sizeBytes;
              });
            }
          },
          child: Text(_mediaUrl.isEmpty ? 'Attach' : 'Change'),
        ),
      ],
    );
  }

  Widget _scheduleRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Schedule: ${formatScheduleSlot(_scheduledTime)}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: () async {
            final picked = await showScheduleTimePicker(
              context: context,
              initial: _scheduledTime,
            );
            if (picked != null && mounted) setState(() => _scheduledTime = picked);
          },
          child: const Text('Change'),
        ),
      ],
    );
  }

  Widget _repeatPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: LemaTheme.s2,
          children: [
            for (final (value, label) in const [
              (recurrenceNone, 'Once'),
              (recurrenceDaily, 'Daily'),
              (recurrenceWeekly, 'Weekly'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _recurrence == value,
                onSelected: (_) => setState(() => _recurrence = value),
              ),
          ],
        ),
        if (_recurrence == recurrenceWeekly) ...[
          const SizedBox(height: LemaTheme.s2),
          // With no days picked, weekly uses the scheduled day.
          Wrap(
            spacing: LemaTheme.s1,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(DateFormat.E().format(DateTime(2024, 1, d))),
                  selected: _days.contains(d),
                  onSelected: (on) =>
                      setState(() => on ? _days.add(d) : _days.remove(d)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _preview() {
    final scheme = Theme.of(context).colorScheme;
    final selection = _orderedSelection;
    if (selection.isEmpty) {
      return Text(
        'Pick a platform to preview.',
        style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
      );
    }
    final active = selection.contains(_active) ? _active : selection.first;
    final name = platformsMap[active]!.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: LemaTheme.s2,
          runSpacing: LemaTheme.s2,
          children: [
            for (final p in selection)
              ChoiceChip(
                label: Text(platformsMap[p]!.name),
                selected: p == active,
                onSelected: (_) => setState(() => _active = p),
              ),
          ],
        ),
        const SizedBox(height: LemaTheme.s3),
        PlatformPreview(
          platform: active,
          caption: _captionFor(active),
          mediaUrl: _mediaUrl,
          isVideo: _isVideo,
          scheduledTime: _scheduledTime,
        ),
        const SizedBox(height: LemaTheme.s2),
        Text(
          platformRules[active]!.tip,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: LemaTheme.s4),
        TextField(
          // Keyed by platform so each keeps its own text and cursor.
          key: ValueKey('override_$active'),
          controller: _overrides[active],
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Different text for $name',
            hintText: 'Leave empty to use the main post',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
