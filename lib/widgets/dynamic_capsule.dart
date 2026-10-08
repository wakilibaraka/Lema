import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/apple_theme.dart';

class DynamicCapsule extends StatelessWidget {
  final VoidCallback? onTap;

  const DynamicCapsule({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.activeProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isDaemonOnline = app.isDaemonOnline;
    final isSandbox = app.sandboxMode;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000).withOpacity(0.85) : const Color(0xFF1D1D1F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDaemonOnline
                    ? (isSandbox ? AppleTheme.systemBlue : AppleTheme.systemGreen)
                    : AppleTheme.systemOrange,
                boxShadow: [
                  BoxShadow(
                    color: (isDaemonOnline
                            ? (isSandbox ? AppleTheme.systemBlue : AppleTheme.systemGreen)
                            : AppleTheme.systemOrange)
                        .withOpacity(0.7),
                    blurRadius: 8,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Profile & Status
            Text(
              profile?.instagramHandle ?? '@emmsdigitalmedia',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 12,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(width: 8),
            Text(
              isDaemonOnline
                  ? (isSandbox ? 'SANDBOX ACTIVE' : 'DAEMON 3001')
                  : 'OFFLINE SYNC',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              CupertinoIcons.chevron_down,
              color: Colors.white.withOpacity(0.5),
              size: 11,
            ),
          ],
        ),
      ),
    );
  }
}
