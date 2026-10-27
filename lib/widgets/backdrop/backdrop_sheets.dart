import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/post_model.dart';
import '../../providers/posts_provider.dart';
import '../../theme/backdrop_theme.dart';
import '../../views/card_detail_view.dart';

/// Backdrop header's search circle: find a post across the existing queue
/// and jump to its card detail. Presentation-only — no new data layer.
Future<void> showFindPostSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FindPostSheet(),
  );
}

/// Backdrop header's bell circle: queue health from real provider state —
/// overdue scheduled posts and failed dispatches. Empty state: "All caught
/// up". No invented counts.
Future<void> showQueueHealthSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QueueHealthSheet(),
  );
}

Widget _sheetFrame(BuildContext context, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    decoration: BoxDecoration(
      color: BackdropTheme.card(isDark),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
    ),
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
    child: SafeArea(top: false, child: child),
  );
}

Widget _grabber(bool isDark) {
  return Center(
    child: Container(
      width: 38,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _FindPostSheet extends StatefulWidget {
  const _FindPostSheet();

  @override
  State<_FindPostSheet> createState() => _FindPostSheetState();
}

class _FindPostSheetState extends State<_FindPostSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posts = context.read<PostsProvider>().posts;
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? <PostModel>[]
        : posts
            .where((p) =>
                p.title.toLowerCase().contains(q) ||
                p.caption.toLowerCase().contains(q))
            .toList();

    return _sheetFrame(
      context,
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grabber(isDark),
            const SizedBox(height: 12),
            Text(
              'Find a post',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: BackdropTheme.ink(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                key: const ValueKey('backdrop_find_field'),
                controller: _controller,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(
                  fontSize: 14,
                  color: BackdropTheme.ink(isDark),
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  hintText: 'Search titles and captions',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: BackdropTheme.inkTertiary(isDark),
                  ),
                  prefixIcon: Icon(
                    CupertinoIcons.search,
                    size: 17,
                    color: BackdropTheme.inkTertiary(isDark),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: q.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'Type to search your queue.',
                        style: TextStyle(
                          fontSize: 13,
                          color: BackdropTheme.inkSecondary(isDark),
                        ),
                      ),
                    )
                  : matches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'No posts match "$_query".',
                            style: TextStyle(
                              fontSize: 13,
                              color: BackdropTheme.inkSecondary(isDark),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: matches.length,
                          itemBuilder: (context, i) =>
                              _PostRow(post: matches[i], isDark: isDark),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueHealthSheet extends StatelessWidget {
  const _QueueHealthSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final posts = context.read<PostsProvider>().posts;
    final overdue = posts.where((p) => p.isOverdue).toList();
    final failed = posts.where((p) => p.status == 'failed').toList();

    return _sheetFrame(
      context,
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _grabber(isDark),
            const SizedBox(height: 12),
            Text(
              'Queue health',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: BackdropTheme.ink(isDark),
              ),
            ),
            const SizedBox(height: 8),
            if (overdue.isEmpty && failed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 34,
                        color: CupertinoColors.systemGreen,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All caught up',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: BackdropTheme.inkSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (overdue.isNotEmpty) ...[
                      _sectionLabel('OVERDUE · ${overdue.length}', isDark),
                      for (final p in overdue)
                        _PostRow(post: p, isDark: isDark, note: 'Was due'),
                    ],
                    if (failed.isNotEmpty) ...[
                      _sectionLabel('FAILED · ${failed.length}', isDark),
                      for (final p in failed)
                        _PostRow(post: p, isDark: isDark, note: 'Dispatch failed'),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: BackdropTheme.inkTertiary(isDark),
          ),
        ),
      );
}

class _PostRow extends StatelessWidget {
  final PostModel post;
  final bool isDark;
  final String? note;

  const _PostRow({required this.post, required this.isDark, this.note});

  @override
  Widget build(BuildContext context) {
    final info = post.platformInfo;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(CardDetailView.route(post));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: info.accentColor.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(info.iconData, size: 16, color: info.accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: BackdropTheme.ink(isDark),
                    ),
                  ),
                  Text(
                    note != null ? '$note · ${info.name}' : info.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: BackdropTheme.inkSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 15,
              color: BackdropTheme.inkTertiary(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
