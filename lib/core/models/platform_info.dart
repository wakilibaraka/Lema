import 'package:flutter/material.dart';

enum SocialPlatform {
  instagram,
  tiktok,
  youtube,
  facebook,
  linkedin,
  twitter,
}

class PlatformInfo {
  final String id;
  final String name;
  final String badge;
  final Color primaryColor;
  final Color accentColor;
  final String handle;
  final String followers;
  final IconData iconData;

  const PlatformInfo({
    required this.id,
    required this.name,
    required this.badge,
    required this.primaryColor,
    required this.accentColor,
    required this.handle,
    required this.followers,
    required this.iconData,
  });

  Color get color => accentColor;

  static PlatformInfo fromPlatform(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.instagram:
        return platformsMap['instagram']!;
      case SocialPlatform.tiktok:
        return platformsMap['tiktok']!;
      case SocialPlatform.youtube:
        return platformsMap['youtube']!;
      case SocialPlatform.facebook:
        return platformsMap['facebook']!;
      case SocialPlatform.linkedin:
        return platformsMap['linkedin']!;
      case SocialPlatform.twitter:
        return platformsMap['twitter']!;
    }
  }

  static PlatformInfo fromString(String platformStr) {
    final key = platformStr.toLowerCase().trim();
    return platformsMap[key] ?? platformsMap['instagram']!;
  }
}

final Map<String, PlatformInfo> platformsMap = {
  'tiktok': const PlatformInfo(
    id: 'tiktok',
    name: 'TikTok',
    badge: 'TikTok',
    primaryColor: Colors.black,
    accentColor: Color(0xFFFE2C55),
    handle: '@emmsdigitalmedia',
    followers: '52.4K',
    iconData: Icons.music_note,
  ),
  'instagram': const PlatformInfo(
    id: 'instagram',
    name: 'Instagram',
    badge: 'IG Reels',
    primaryColor: Color(0xFFE1306C),
    accentColor: Color(0xFFF56040),
    handle: '@emmsdigitalmedia',
    followers: '28.6K',
    iconData: Icons.camera_alt,
  ),
  'facebook': const PlatformInfo(
    id: 'facebook',
    name: 'Facebook',
    badge: 'Facebook',
    primaryColor: Color(0xFF1877F2),
    accentColor: Color(0xFF1877F2),
    handle: 'Emms Digital Media',
    followers: '15.1K',
    iconData: Icons.facebook,
  ),
  'youtube': const PlatformInfo(
    id: 'youtube',
    name: 'YouTube',
    badge: 'YT Shorts',
    primaryColor: Color(0xFFFF0000),
    accentColor: Color(0xFFFF0000),
    handle: 'Emms Digital Media',
    followers: '8.4K',
    iconData: Icons.play_arrow,
  ),
  'linkedin': const PlatformInfo(
    id: 'linkedin',
    name: 'LinkedIn',
    badge: 'LinkedIn',
    primaryColor: Color(0xFF0077B5),
    accentColor: Color(0xFF0077B5),
    handle: 'Emmanuel Baraka',
    followers: '6.2K',
    iconData: Icons.business,
  ),
  'twitter': const PlatformInfo(
    id: 'twitter',
    name: 'X (Twitter)',
    badge: 'X',
    primaryColor: Colors.black,
    accentColor: Color(0xFF1DA1F2),
    handle: '@emmsdigital',
    followers: '3.9K',
    iconData: Icons.chat_bubble_outline,
  ),
};
