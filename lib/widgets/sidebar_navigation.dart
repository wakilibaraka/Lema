import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/apple_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.activeProfile;

    final navItems = [
      {'icon': CupertinoIcons.device_phone_portrait, 'label': 'Device Simulator', 'badge': 'Live'},
      {'icon': CupertinoIcons.layers_alt, 'label': 'Publish Queue', 'badge': 'Buffer'},
      {'icon': CupertinoIcons.calendar, 'label': 'Content Calendar', 'badge': null},
      {'icon': CupertinoIcons.sparkles, 'label': 'AI Studio', 'badge': 'Gemini'},
      {'icon': CupertinoIcons.film, 'label': 'Hooks & Scripts', 'badge': '60s'},
      {'icon': CupertinoIcons.checkmark_circle, 'label': 'Daily Tick', 'badge': null},
      {'icon': CupertinoIcons.gear_alt, 'label': 'Daemon & Settings', 'badge': null},
    ];

    if (isRail) {
      return Container(
        width: 76,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131317).withAlpha(210) : const Color(0xFFF9F9FB).withAlpha(220),
          border: Border(
            right: BorderSide(
              color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(12),
              width: 1,
            ),
          ),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Compact Avatar
                Tooltip(
                  message: '${profile.name} (${profile.instagramHandle})',
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          profile.avatarUrl.isNotEmpty ? profile.avatarUrl : 'assets/emms_avatar.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 36,
                            height: 36,
                            color: AppleTheme.systemBlue,
                            child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppleTheme.systemBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Compact Nav Items
                Expanded(
                  child: ListView.builder(
                    itemCount: navItems.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final item = navItems[index];
                      final isSelected = selectedIndex == index;
                      final iconData = item['icon'] as IconData;
                      final label = item['label'] as String;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Tooltip(
                          message: label,
                          child: InkWell(
                            onTap: () => onDestinationSelected(index),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppleTheme.systemBlue.withAlpha(isDark ? 50 : 30)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: AppleTheme.systemBlue.withAlpha(80), width: 1)
                                    : null,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    iconData,
                                    size: 20,
                                    color: isSelected
                                        ? AppleTheme.systemBlue
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  if (item['badge'] != null)
                                    Positioned(
                                      top: 8,
                                      right: 12,
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppleTheme.systemGreen,
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
                    },
                  ),
                ),

                // Bottom Rail Actions
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                          size: 18,
                          color: isDark ? AppleTheme.systemIndigo : AppleTheme.systemOrange,
                        ),
                        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                        onPressed: () => app.toggleTheme(),
                      ),
                      const SizedBox(height: 4),
                      Tooltip(
                        message: app.isDaemonOnline ? 'Daemon Port 3001 Active' : 'Sandbox Mode',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: app.isDaemonOnline ? AppleTheme.systemGreen : AppleTheme.systemOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Full Sidebar (Width: 250px)
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131317).withAlpha(210) : const Color(0xFFF9F9FB).withAlpha(220),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(12),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Active Profile Card (Emms Digital Media)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(12) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        profile.avatarUrl.isNotEmpty ? profile.avatarUrl : 'assets/emms_avatar.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 38,
                          height: 38,
                          color: AppleTheme.systemBlue,
                          child: const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
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
                                    color: isDark ? Colors.white : Colors.black,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.checkmark_seal_fill, color: AppleTheme.systemBlue, size: 13),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.instagramHandle,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Navigation Links
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  itemCount: navItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 3),
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = selectedIndex == index;
                    final iconData = item['icon'] as IconData;
                    final label = item['label'] as String;
                    final badge = item['badge'] as String?;

                    return InkWell(
                      onTap: () => onDestinationSelected(index),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppleTheme.systemBlue.withAlpha(isDark ? 55 : 35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(
                                  color: AppleTheme.systemBlue.withAlpha(isDark ? 100 : 70),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              iconData,
                              size: 18,
                              color: isSelected
                                  ? AppleTheme.systemBlue
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? Colors.white : AppleTheme.systemBlue)
                                      : (isDark ? Colors.white70 : Colors.black87),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppleTheme.systemBlue
                                      : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badge,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Section: Theme & Daemon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(12),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Theme Switcher Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
                              size: 15,
                              color: isDark ? AppleTheme.systemIndigo : AppleTheme.systemOrange,
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
                          activeTrackColor: AppleTheme.systemBlue,
                          onChanged: (_) => app.toggleTheme(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Daemon Status Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: app.isDaemonOnline ? AppleTheme.systemGreen : AppleTheme.systemOrange,
                              boxShadow: [
                                BoxShadow(
                                  color: (app.isDaemonOnline ? AppleTheme.systemGreen : AppleTheme.systemOrange).withAlpha(120),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              app.isDaemonOnline ? 'Port 3001 Active' : 'Sandbox Simulated',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
