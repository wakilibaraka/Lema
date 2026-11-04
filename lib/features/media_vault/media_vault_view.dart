import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/media_asset.dart';
import '../../core/providers/app_provider.dart';
import '../../core/providers/media_provider.dart';
import '../../core/theme.dart';
import '../../widgets/media_picker_dialog.dart';
import '../../widgets/media_player_widget.dart';

const _audioExtensions = ['.mp3', '.m4a', '.wav', '.aac'];

/// Reusable media: search it, filter it by tag, send it to the composer.
class MediaVaultView extends StatefulWidget {
  const MediaVaultView({super.key});

  @override
  State<MediaVaultView> createState() => _MediaVaultViewState();
}

class _MediaVaultViewState extends State<MediaVaultView> {
  String? _tag;
  String _query = '';

  Future<void> _add() async {
    final media = context.read<MediaProvider>();
    final picked = await MediaPickerDialog.show(context);
    if (picked == null || !mounted) return;
    final tags = await _askForTags(context, picked.name, const []);
    if (tags == null) return;
    final path = picked.pathOrUrl.toLowerCase().split('?').first;
    final now = DateTime.now();
    media.add(MediaAsset(
      id: 'asset_${now.millisecondsSinceEpoch}',
      url: picked.pathOrUrl,
      name: picked.name,
      kind: picked.isVideo
          ? kindVideo
          : _audioExtensions.any(path.endsWith)
              ? kindAudio
              : kindImage,
      tags: tags,
      addedAt: now,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaProvider>();
    final scheme = Theme.of(context).colorScheme;
    final tags = media.allTags;
    // A filter can outlive the last asset carrying its tag.
    final tag = tags.contains(_tag) ? _tag : null;
    final shown = filterAssets(media.assets, tag: tag, query: _query);
    return Padding(
      padding: const EdgeInsets.fromLTRB(LemaTheme.s4, LemaTheme.s4, LemaTheme.s4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search name or tag',
                    prefixIcon: Icon(CupertinoIcons.search, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: LemaTheme.s3),
              FilledButton(onPressed: _add, child: const Text('Add')),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: LemaTheme.s3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: LemaTheme.s2),
                      child: FilterChip(
                        label: Text(t),
                        selected: t == tag,
                        onSelected: (on) => setState(() => _tag = on ? t : null),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: LemaTheme.s3),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      media.assets.isEmpty ? 'No media yet' : 'Nothing matches',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(bottom: LemaTheme.s8 * 2),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: LemaTheme.s3,
                      crossAxisSpacing: LemaTheme.s3,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _AssetTile(asset: shown[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final MediaAsset asset;

  const _AssetTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${asset.kind}: ${asset.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(LemaTheme.radiusControl),
        onTap: () => _showActions(context, asset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(LemaTheme.radiusControl),
                child: asset.kind == kindAudio
                    ? ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(CupertinoIcons.music_note),
                      )
                    : IgnorePointer(
                        child: UniversalMediaPlayer(
                          mediaUrl: asset.url,
                          isVideo: asset.isVideo,
                          autoPlay: false,
                          showControls: false,
                          thumbnail: true,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: LemaTheme.s2),
            Text(
              asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              asset.tags.isEmpty ? asset.kind : '${asset.kind} · ${asset.tags.join(', ')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

void _showActions(BuildContext context, MediaAsset asset) {
  final media = context.read<MediaProvider>();
  final app = context.read<AppProvider>();
  final messenger = ScaffoldMessenger.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(asset.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          // The composer has nothing to attach audio to.
          if (asset.kind != kindAudio)
            ListTile(
              title: const Text('Use in post'),
              onTap: () {
                Navigator.of(sheet).pop();
                app.useInPost(asset);
              },
            ),
          ListTile(
            title: const Text('Edit tags'),
            onTap: () async {
              Navigator.of(sheet).pop();
              final tags = await _askForTags(context, asset.name, asset.tags);
              if (tags != null) media.setTags(asset.id, tags);
            },
          ),
          ListTile(
            title: const Text('Remove from vault'),
            onTap: () {
              Navigator.of(sheet).pop();
              media.remove(asset.id);
              messenger.showSnackBar(SnackBar(
                content: const Text('Removed from vault'),
                action: SnackBarAction(label: 'Undo', onPressed: () => media.add(asset)),
              ));
            },
          ),
        ],
      ),
    ),
  );
}

/// Null means the user cancelled.
Future<List<String>?> _askForTags(BuildContext context, String name, List<String> current) {
  final controller = TextEditingController(text: current.join(', '));
  return showDialog<List<String>>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Tags'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: name, hintText: 'reel, promo'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(dialog).pop(parseTags(controller.text)),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
