import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/device_preview_model.dart';
import '../../models/platform_info.dart';
import '../../models/post_model.dart';
import '../media_player_widget.dart';

class UniversalDeviceFrame extends StatelessWidget {
  final DeviceSpec device;
  final PreviewOrientation orientation;
  final Widget child;
  final bool isDark;
  final SocialPlatform platform;
  final PostModel post;
  final String authorName;
  final String handle;
  final String mediaUrl;
  final bool isVideo;

  const UniversalDeviceFrame({
    super.key,
    required this.device,
    required this.orientation,
    required this.child,
    required this.isDark,
    required this.platform,
    required this.post,
    required this.authorName,
    required this.handle,
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    switch (device.category) {
      case DeviceCategory.iphone:
        return _buildIPhoneChassis();
      case DeviceCategory.android:
        return _buildAndroidChassis();
      case DeviceCategory.tablet:
        return _buildTabletChassis();
      case DeviceCategory.laptop:
        return _buildLaptopChassis();
      case DeviceCategory.tv:
        return _buildSmartTvChassis();
    }
  }

  // 1. iPhone 16 Pro Chassis
  Widget _buildIPhoneChassis() {
    return Container(
      width: device.width,
      height: device.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F),
        borderRadius: BorderRadius.circular(device.cornerRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF383842) : const Color(0xFF26262B),
          width: device.bezelWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 160 : 70),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: (post.platformInfo.color).withAlpha(35),
            blurRadius: 60,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(device.cornerRadius - 4),
        child: Stack(
          children: [
            Positioned.fill(child: child),

            // Dynamic Island (iPhone 16 Pro)
            Positioned(
              top: 11,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 120,
                  height: 31,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF13131D),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF232333), width: 1.5),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F1826),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top Status Indicators
            Positioned(
              top: 15,
              left: 28,
              child: const Text(
                '9:41',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Positioned(
              top: 15,
              right: 26,
              child: Row(
                children: const [
                  Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Icon(CupertinoIcons.wifi, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Icon(CupertinoIcons.battery_100, color: Colors.white, size: 16),
                ],
              ),
            ),

            // Bottom Home Bar
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 135,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Samsung Galaxy S24 Ultra (Android) Chassis
  Widget _buildAndroidChassis() {
    return Container(
      width: device.width,
      height: device.height,
      decoration: BoxDecoration(
        color: const Color(0xFF060608),
        borderRadius: BorderRadius.circular(device.cornerRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E38) : const Color(0xFF222228),
          width: device.bezelWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 160 : 70),
            blurRadius: 46,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: const Color(0xFF1877F2).withAlpha(25),
            blurRadius: 55,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(device.cornerRadius - 3),
        child: Stack(
          children: [
            Positioned.fill(child: child),

            // Center Punch-hole Camera
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF22222B), width: 1.5),
                  ),
                ),
              ),
            ),

            // Android One UI Status Bar
            Positioned(
              top: 8,
              left: 20,
              child: Row(
                children: const [
                  Text(
                    '12:45',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(CupertinoIcons.bell_fill, color: Colors.white70, size: 10),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 20,
              child: Row(
                children: const [
                  Text(
                    '5G',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 5),
                  Icon(CupertinoIcons.wifi, color: Colors.white, size: 12),
                  SizedBox(width: 5),
                  Text(
                    '98%',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 3),
                  Icon(CupertinoIcons.battery_100, color: Colors.white, size: 14),
                ],
              ),
            ),

            // Android Bottom Gesture Pill
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 90,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(160),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. iPad Pro 13" (Tablet) Chassis
  Widget _buildTabletChassis() {
    return Container(
      width: device.width,
      height: device.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(device.cornerRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF383844) : const Color(0xFF2B2B33),
          width: device.bezelWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 160 : 70),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(device.cornerRadius - 4),
        child: Stack(
          children: [
            // Tablet Content Layout (Dual-pane / spacious preview)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Row(
                  children: [
                    // Main Media Player
                    Expanded(
                      flex: 6,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: UniversalMediaPlayer(
                              mediaUrl: mediaUrl,
                              isVideo: isVideo,
                              fit: BoxFit.contain,
                              autoPlay: true,
                              showControls: true,
                            ),
                          ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(150),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(post.platformInfo.iconData, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${post.platformInfo.name} Tablet Feed',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Tablet Context Column
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141419),
                          border: Border(left: BorderSide(color: Colors.white.withAlpha(16))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(radius: 20, backgroundImage: AssetImage('assets/emms_avatar.png')),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text(handle, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  post.caption,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildPillMetric(CupertinoIcons.heart_fill, post.likes, Colors.redAccent),
                                _buildPillMetric(CupertinoIcons.bubble_left_fill, '${post.comments}', Colors.white70),
                                _buildPillMetric(CupertinoIcons.share, 'Share', Colors.white70),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top Camera Sensor on Bezel
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22222A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            // Bottom iPadOS Home Bar
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 160,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. MacBook Pro 16" (Laptop) Chassis
  Widget _buildLaptopChassis() {
    return Container(
      width: device.width,
      height: device.height,
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(device.cornerRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF33333F) : const Color(0xFF25252D),
          width: device.bezelWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 180 : 80),
            blurRadius: 54,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(device.cornerRadius - 4),
        child: Column(
          children: [
            // Browser Title Bar with URL
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: const Color(0xFF1E1E26),
              child: Row(
                children: [
                  // Traffic Lights
                  Row(
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Browser URL Bar
                  Expanded(
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(120),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.lock_fill, color: Colors.white54, size: 10),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'https://${post.platformInfo.name.toLowerCase()}.com/$handle/p/${post.id}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(CupertinoIcons.arrow_clockwise, color: Colors.white54, size: 13),
                ],
              ),
            ),

            // Laptop Desktop Web View
            Expanded(
              child: Container(
                color: const Color(0xFF0C0C0F),
                child: Row(
                  children: [
                    // Video Player
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: Colors.black,
                        child: UniversalMediaPlayer(
                          mediaUrl: mediaUrl,
                          isVideo: isVideo,
                          fit: BoxFit.contain,
                          autoPlay: true,
                          showControls: true,
                        ),
                      ),
                    ),
                    // Desktop Sidebar
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141419),
                          border: Border(left: BorderSide(color: Colors.white.withAlpha(16))),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(radius: 18, backgroundImage: AssetImage('assets/emms_avatar.png')),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text(handle, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  post.caption,
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
                                ),
                              ),
                            ),
                            const Divider(color: Colors.white12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${post.likes} Likes', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text('${post.comments} Comments', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Smart TV 4K Chassis
  Widget _buildSmartTvChassis() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // TV Panel
        Container(
          width: device.width,
          height: device.height,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(device.cornerRadius),
            border: Border.all(
              color: const Color(0xFF2B2B33),
              width: device.bezelWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(200),
                blurRadius: 60,
                offset: const Offset(0, 24),
              ),
              BoxShadow(
                color: post.platformInfo.color.withAlpha(40),
                blurRadius: 80,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(device.cornerRadius - 2),
            child: Stack(
              children: [
                // Fullscreen TV Video Player
                Positioned.fill(
                  child: UniversalMediaPlayer(
                    mediaUrl: mediaUrl,
                    isVideo: isVideo,
                    fit: BoxFit.contain,
                    autoPlay: true,
                    showControls: false,
                  ),
                ),

                // TV Overlay Header
                Positioned(
                  top: 24,
                  left: 28,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(180),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.tv, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${post.platformInfo.name} TV Experience (4K Ultra HD)',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom HUD with Remote Control Navigation
                Positioned(
                  left: 28,
                  right: 28,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(190),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(30)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 20, backgroundImage: AssetImage('assets/emms_avatar.png')),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(authorName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(height: 3),
                              Text(
                                post.caption,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Remote Prompts
                        Row(
                          children: [
                            _buildRemotePrompt('◀', 'Prev'),
                            const SizedBox(width: 8),
                            _buildRemotePrompt('OK', 'Pause'),
                            const SizedBox(width: 8),
                            _buildRemotePrompt('▶', 'Next'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // TV Stand Chin
        Container(
          width: 180,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(150),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRemotePrompt(String keyLabel, String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              keyLabel,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 9.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(action, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPillMetric(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
