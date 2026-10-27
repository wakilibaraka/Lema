import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nav_destination.dart';
import '../models/profile_model.dart';
import '../providers/app_provider.dart';
import '../providers/posts_provider.dart';
import '../providers/profile_provider.dart';
import '../services/demo_mode_service.dart';
import '../theme/backdrop_theme.dart';

/// A live count on a navigation row.
class _NavBadge {
  final String label;
  final Color color;

  const _NavBadge(this.label, this.color);
}

/// The desktop navigation rail (tablet widths) and the full sidebar (desktop)
/// in the Backdrop language.
///
/// These were two near-identical ~200-line branches that had already drifted
/// apart, so every colour change had to be made twice. One body now renders
/// both: [isRail] switches the width and the per-row presentation, never the
/// tokens.
class SidebarNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool isRail;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.isRail = false,
  });

  static const double railWidth = 76;
  static const double sidebarWidth = 250;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppProvider>();
    final profile = context.watch<ProfileProvider>().activeProfile;

    final navItems = lemaDestinations;

    // Badges are counts, not decoration. They used to be static strings
    // ('New', 'Live', 'Buffer', 'Gemini', '60s') that said nothing about the
    // user's actual queue.
    final posts = context.watch<PostsProvider>();
    final overdueCount = posts.overduePosts.length;
    final badges = <int, _NavBadge>{
      if (posts.scheduledPosts.isNotEmpty)
        2: _NavBadge('${posts.scheduledPosts.length}', BackdropTheme.accent),
      if (overdueCount > 0)
        9: _NavBadge('$overdueCount', BackdropTheme.statusWarning),
    };

    // One honest daemon state, shared with Settings.
    final daemonLabel = app.isDaemonOnline
        ? 'Daemon on port 3001'
        : DemoModeService.isEnabled
        ? 'Demo mode (local publish)'
        : 'Daemon offline';

    return Container(
      width: isRail ? railWidth : sidebarWidth,
      decoration: BoxDecoration(
        color: BackdropTheme.chrome(isDark),
        border: Border(
          right: BorderSide(color: BackdropTheme.hairline(isDark), width: 1),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            crossAxisAlignment: isRail
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            children: [
              isRail
                  ? _RailHeader(profile: profile, isDark: isDark)
                  : _FullHeader(profile: profile, isDark: isDark),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: isRail
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
                      : const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  itemCount: navItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 3),
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = selectedIndex == index;
                    final badge = badges[index];

                    void onTap() => onDestinationSelected(index);

                    return isRail
                        ? _RailRow(
                            item: item,
                            isSelected: isSelected,
                            badge: badge,
                            isDark: isDark,
                            onTap: onTap,
                          )
                        : _FullRow(
                            item: item,
                            isSelected: isSelected,
                            badge: badge,
                            isDark: isDark,
                            onTap: onTap,
                          );
                  },
                ),
              ),
              const Divider(height: 1),
              if (isRail)
                _RailFooter(
                  isDark: isDark,
                  isDaemonOnline: app.isDaemonOnline,
                  daemonLabel: daemonLabel,
                  onToggleTheme: app.toggleTheme,
                )
              else
                _FullFooter(
                  isDark: isDark,
                  isDaemonOnline: app.isDaemonOnline,
                  daemonLabel: daemonLabel,
                  onToggleTheme: app.toggleTheme,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The profile avatar, shared by both widths. [size] and [radius] are the only
/// things the rail and the sidebar disagree about.
class _Avatar extends StatelessWidget {
  final ProfileModel profile;
  final double size;
  final double radius;

  const _Avatar({
    required this.profile,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        profile.avatarUrl.isNotEmpty
            ? profile.avatarUrl
            : 'assets/emms_avatar.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: BackdropTheme.accent,
          child: Icon(
            CupertinoIcons.person_fill,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _RailHeader({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
      child: Tooltip(
        message: '${profile.name} (${profile.instagramHandle})',
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            _Avatar(profile: profile, size: 36, radius: 12),
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: BackdropTheme.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullHeader extends StatelessWidget {
  final ProfileModel profile;
  final bool isDark;

  const _FullHeader({required this.profile, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BackdropTheme.cardDecoration(isDark, radius: 14).copyWith(
        color: isDark ? Colors.white.withAlpha(12) : Colors.white,
      ),
      child: Row(
        children: [
          _Avatar(profile: profile, size: 38, radius: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: BackdropTheme.ink(isDark),
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: BackdropTheme.accent,
                      size: 13,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  profile.instagramHandle,
                  style: TextStyle(
                    fontSize: 11,
                    color: BackdropTheme.inkSecondary(isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  final NavDestination item;
  final bool isSelected;
  final _NavBadge? badge;
  final bool isDark;
  final VoidCallback onTap;

  const _RailRow({
    required this.item,
    required this.isSelected,
    required this.badge,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: badge == null ? item.label : '${item.label} · ${badge!.label}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BackdropTheme.radiusControl),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 48,
            decoration: BoxDecoration(
              color: isSelected ? BackdropTheme.navSelected(isDark) : null,
              borderRadius: BorderRadius.circular(BackdropTheme.radiusControl),
              border: isSelected
                  ? Border.all(
                      color: BackdropTheme.navSelectedBorder(isDark),
                      width: 1,
                    )
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isSelected
                      ? BackdropTheme.accent
                      : BackdropTheme.inkSecondary(isDark),
                ),
                if (badge != null)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: badge!.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullRow extends StatelessWidget {
  final NavDestination item;
  final bool isSelected;
  final _NavBadge? badge;
  final bool isDark;
  final VoidCallback onTap;

  const _FullRow({
    required this.item,
    required this.isSelected,
    required this.badge,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? BackdropTheme.navSelected(isDark) : null,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(
                  color: BackdropTheme.navSelectedBorder(isDark),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 18,
              color: isSelected
                  ? BackdropTheme.accent
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : BackdropTheme.accent)
                      : (isDark ? Colors.white70 : Colors.black87),
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? BackdropTheme.accent
                      : badge!.color.withAlpha(isDark ? 45 : 30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!.label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : badge!.color,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  final bool isDark;
  final bool isDaemonOnline;
  final String daemonLabel;
  final VoidCallback onToggleTheme;

  const _RailFooter({
    required this.isDark,
    required this.isDaemonOnline,
    required this.daemonLabel,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          IconButton(
            icon: Icon(
              isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
              size: 18,
              color:
                  isDark ? BackdropTheme.violet : BackdropTheme.statusWarning,
            ),
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: onToggleTheme,
          ),
          const SizedBox(height: 4),
          Tooltip(
            message: daemonLabel,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isDaemonOnline
                    ? BackdropTheme.statusOnline
                    : BackdropTheme.statusWarning,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullFooter extends StatelessWidget {
  final bool isDark;
  final bool isDaemonOnline;
  final String daemonLabel;
  final VoidCallback onToggleTheme;

  const _FullFooter({
    required this.isDark,
    required this.isDaemonOnline,
    required this.daemonLabel,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isDaemonOnline
        ? BackdropTheme.statusOnline
        : BackdropTheme.statusWarning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          // Theme Switcher Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isDark
                        ? CupertinoIcons.moon_fill
                        : CupertinoIcons.sun_max_fill,
                    size: 15,
                    color: isDark
                        ? BackdropTheme.violet
                        : BackdropTheme.statusWarning,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              CupertinoSwitch(
                value: isDark,
                activeTrackColor: BackdropTheme.accent,
                onChanged: (_) => onToggleTheme(),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Daemon Status Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(10)
                  : Colors.black.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(color: statusColor.withAlpha(120), blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    daemonLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
