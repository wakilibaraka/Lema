import 'package:flutter/material.dart';

import '../../core/models/platform_info.dart';
import '../../core/models/post_model.dart';
import '../../core/theme.dart';
import '../../core/widgets/on_air_tick.dart';
import '../../widgets/media_player_widget.dart';

/// Roughly how the post reads on one platform.
class PlatformPreview extends StatelessWidget {
  final String platform;
  final String caption;
  final String mediaUrl;
  final bool isVideo;
  final DateTime scheduledTime;

  const PlatformPreview({
    super.key,
    required this.platform,
    required this.caption,
    required this.mediaUrl,
    required this.isVideo,
    required this.scheduledTime,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = PlatformInfo.fromString(platform);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LemaTheme.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: LemaTheme.s2),
                Expanded(
                  child: Text(
                    info.handle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                OnAirTick(
                  post: PostModel(
                    id: 'preview',
                    caption: caption,
                    mediaUrl: mediaUrl,
                    scheduledTime: scheduledTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: LemaTheme.s3),
            if (mediaUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(LemaTheme.radiusControl),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: UniversalMediaPlayer(
                    mediaUrl: mediaUrl,
                    isVideo: isVideo,
                    autoPlay: false,
                    showControls: false,
                    thumbnail: true,
                  ),
                ),
              ),
              const SizedBox(height: LemaTheme.s3),
            ],
            Text(
              caption.isEmpty ? 'Nothing written yet.' : caption,
              style: TextStyle(
                fontSize: 13,
                color: caption.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
