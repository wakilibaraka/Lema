import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/media_vault/media_vault_view.dart';
import '../features/queue_calendar/queue_calendar_view.dart';
import '../views/analytics_view.dart';
import '../views/composer_view.dart';
import '../views/settings_view.dart';
import 'destinations.dart';
import 'providers/app_provider.dart';
import 'theme.dart';

/// Widths at which the shell changes shape.
const double kSidebarBreakpoint = 900;
const double kRailBreakpoint = 600;

/// The app frame: a collapsible sidebar on desktop, a rail on tablets, and a
/// bottom bar with a quick-draft button on phones.
class LemaShell extends StatelessWidget {
  const LemaShell({super.key});

  static const List<Widget> _views = [
    AnalyticsView(),
    QueueCalendarView(),
    ComposerView(),
    MediaVaultView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final width = MediaQuery.sizeOf(context).width;
    // An index saved by an older build can point past the five destinations.
    final index = app.selectedNavIndex.clamp(0, _views.length - 1);
    final page = _views[index];

    if (width >= kRailBreakpoint) {
      final collapsed = width < kSidebarBreakpoint || app.sidebarCollapsed;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _Sidebar(
                collapsed: collapsed,
                canToggle: width >= kSidebarBreakpoint,
                selected: index,
                onSelect: app.setNavIndex,
                onToggle: app.toggleSidebar,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          ),
        ),
      );
    }

    final media = MediaQuery.of(context);
    final onComposer = index == composerDestinationIndex;
    return MediaQuery(
      // The phone shell caps text scaling so the bars stay legible.
      data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 1.2)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(lemaDestinations[index].label),
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
        body: page,
        floatingActionButton: onComposer
            ? null
            : FloatingActionButton(
                key: const ValueKey('quick_draft'),
                tooltip: 'New post',
                onPressed: () => showQuickDraftSheet(context),
                child: const Icon(CupertinoIcons.add),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: app.setNavIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in lemaDestinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      ),
    );
  }
}

/// Opens the composer in a sheet so a phone user can draft without leaving
/// the screen they are on.
Future<void> showQuickDraftSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(LemaTheme.radiusSheet)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.92,
      child: ComposerView(),
    ),
  );
}

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final bool canToggle;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;

  const _Sidebar({
    required this.collapsed,
    required this.canToggle,
    required this.selected,
    required this.onSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: collapsed ? 72 : 248,
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: LemaTheme.s3, vertical: LemaTheme.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                if (!collapsed)
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: LemaTheme.s3),
                      child: Text('Lema',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (canToggle)
                  Expanded(
                    flex: collapsed ? 1 : 0,
                    child: IconButton(
                      key: const ValueKey('sidebar_toggle'),
                      tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                      iconSize: 18,
                      onPressed: onToggle,
                      icon: Icon(
                        CupertinoIcons.sidebar_left,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: LemaTheme.s6),
          for (var i = 0; i < lemaDestinations.length; i++) ...[
            _SidebarItem(
              destination: lemaDestinations[i],
              selected: i == selected,
              collapsed: collapsed,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final NavDestination destination;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final row = Material(
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(LemaTheme.radiusControl),
      child: InkWell(
        borderRadius: BorderRadius.circular(LemaTheme.radiusControl),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (!collapsed) const SizedBox(width: LemaTheme.s3),
              Icon(destination.icon, size: 18, color: color),
              if (!collapsed) ...[
                const SizedBox(width: LemaTheme.s3),
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: collapsed ? Tooltip(message: destination.label, child: row) : row,
    );
  }
}
