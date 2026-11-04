import 'package:flutter/material.dart';

import '../../core/models/platform_info.dart';
import '../../core/theme.dart';

/// The hashtag count for the selected platforms, and saved tags to add.
class HashtagField extends StatelessWidget {
  final String caption;
  final List<String> selectedPlatforms;
  final List<String> saved;
  final ValueChanged<String> onAdd;

  const HashtagField({
    super.key,
    required this.caption,
    required this.selectedPlatforms,
    required this.saved,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final count = hashtagCount(caption);
    final capped = selectedPlatforms.where((p) => platformRules[p]?.hashtagCap != null);
    final unused = saved.where((t) => !caption.contains(t)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          capped.isEmpty
              ? 'Hashtags: $count'
              : 'Hashtags: $count of ${platformRules[capped.first]!.hashtagCap} on ${platformsMap[capped.first]!.name}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (unused.isNotEmpty) ...[
          const SizedBox(height: LemaTheme.s2),
          Wrap(
            spacing: LemaTheme.s2,
            runSpacing: LemaTheme.s2,
            children: [
              for (final tag in unused)
                ActionChip(label: Text(tag), onPressed: () => onAdd(tag)),
            ],
          ),
        ],
      ],
    );
  }
}
