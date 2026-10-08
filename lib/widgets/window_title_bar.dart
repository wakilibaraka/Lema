import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/apple_theme.dart';
import 'dynamic_capsule.dart';

class WindowTitleBar extends StatelessWidget {
  final String title;
  final VoidCallback? onNewPost;

  const WindowTitleBar({
    super.key,
    required this.title,
    this.onNewPost,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final app = context.watch<AppProvider>();
    final profile = context.watch<ProfileProvider>().activeProfile;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131317).withAlpha(220) : const Color(0xFFFBFBFD).withAlpha(220),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(12),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Row(
            children: [
              // macOS Traffic Light dots
              Row(
                children: [
                  _buildTrafficDot(const Color(0xFFFF5F56)), // Close
                  const SizedBox(width: 8),
                  _buildTrafficDot(const Color(0xFFFFBD2E)), // Minimize
                  const SizedBox(width: 8),
                  _buildTrafficDot(const Color(0xFF27C93F)), // Maximize
                ],
              ),

              const SizedBox(width: 18),

              // Title & Breadcrumb
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lema',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '/',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Centered Dynamic Island Capsule
              const DynamicCapsule(),

              const Spacer(),

              // Right Actions: Quick Theme Toggle
              Container(
                height: 30,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(16) : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(10),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                    size: 14,
                    color: isDark ? AppleTheme.systemOrange : AppleTheme.systemIndigo,
                  ),
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(),
                  onPressed: () => app.toggleTheme(),
                ),
              ),

              // Active Persona Pill (Shown on wider desktop widths)
              if (screenWidth >= 980) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: AppleTheme.systemBlue.withAlpha(isDark ? 35 : 22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppleTheme.systemBlue.withAlpha(50),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.checkmark_seal_fill, color: AppleTheme.systemBlue, size: 12.5),
                      const SizedBox(width: 6),
                      Text(
                        profile.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppleTheme.systemBlue,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrafficDot(Color color) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withAlpha(30), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(70),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
