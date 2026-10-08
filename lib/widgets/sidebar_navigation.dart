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

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
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

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416).withOpacity(0.85) : const Color(0xFFF2F2F7).withOpacity(0.9),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
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
              // App Brand Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppleTheme.systemBlue, AppleTheme.systemIndigo],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppleTheme.systemBlue.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.paperplane_fill, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lema',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            'Social Auto-Poster',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Active Profile Card (Emms Digital Media)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
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
                        profile?.avatarUrl ?? 'assets/emms_avatar.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
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
                                  profile?.name ?? 'Emms Digital Media',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: -0.2,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(CupertinoIcons.checkmark_seal_fill, color: AppleTheme.systemBlue, size: 13),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            profile?.instagramHandle ?? '@emmsdigitalmedia',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Navigation Links
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: navItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = selectedIndex == index;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppleTheme.systemBlue.withOpacity(0.25) : AppleTheme.systemBlue.withOpacity(0.12))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: AppleTheme.systemBlue.withOpacity(0.3), width: 1)
                            : null,
                      ),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(
                          item['icon'] as IconData,
                          size: 19,
                          color: isSelected
                              ? AppleTheme.systemBlue
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                        title: Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : AppleTheme.systemBlue)
                                : (isDark ? Colors.white.withOpacity(0.85) : Colors.black87),
                          ),
                        ),
                        trailing: item['badge'] != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppleTheme.systemBlue.withOpacity(0.2)
                                      : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item['badge'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppleTheme.systemBlue
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              )
                            : null,
                        onTap: () => onDestinationSelected(index),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Section: Theme & Daemon Pill
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
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
                              size: 16,
                              color: isDark ? AppleTheme.systemIndigo : AppleTheme.systemOrange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isDark ? 'Dark Mode' : 'Light Mode',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        CupertinoSwitch(
                          value: isDark,
                          activeColor: AppleTheme.systemBlue,
                          onChanged: (_) => app.toggleTheme(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Daemon Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: app.isDaemonOnline ? AppleTheme.systemGreen : AppleTheme.systemOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              app.isDaemonOnline ? 'Port 3001 Active' : 'Offline / Standalone',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                          Text(
                            'v1.0.0',
                            style: TextStyle(
                              fontSize: 10,
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
