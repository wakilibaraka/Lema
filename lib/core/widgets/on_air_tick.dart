import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/post_model.dart';
import '../theme.dart';

Color postStatusColor(PostModel post, ColorScheme scheme) =>
    switch (post.postStatus) {
      PostStatus.scheduled => LemaTheme.accent,
      PostStatus.published => LemaTheme.success,
      PostStatus.failed || PostStatus.unknown => LemaTheme.danger,
      PostStatus.draft => scheme.onSurfaceVariant,
    };

String postStatusLabel(PostModel post) => switch (post.postStatus) {
      PostStatus.scheduled => 'Scheduled',
      PostStatus.published => 'Published',
      PostStatus.failed => 'Failed',
      PostStatus.unknown => 'Result unknown',
      PostStatus.draft => 'Draft',
    };

/// Lema's mark for a scheduled item: a monospaced time and a status dot.
class OnAirTick extends StatelessWidget {
  final PostModel post;

  const OnAirTick({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('HH:mm').format(post.scheduledTime),
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Menlo',
            fontFamilyFallback: const ['monospace'],
            fontFeatures: const [FontFeature.tabularFigures()],
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: LemaTheme.s1),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: postStatusColor(post, scheme),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
