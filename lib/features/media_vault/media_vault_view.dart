import 'package:flutter/material.dart';

// shortcut: placeholder until the vault slice adds assets and tags.
class MediaVaultView extends StatelessWidget {
  const MediaVaultView({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Text('No media yet', style: TextStyle(color: muted)),
    );
  }
}
