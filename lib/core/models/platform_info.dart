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

/// What each platform allows in a post. Warnings only: nothing here blocks
/// saving, because these limits change and the user may know better.
class PlatformRules {
  final int captionLimit;
  final int? hashtagCap;
  final int? titleLimit;
  final bool requiresMedia;
  final String tip;

  const PlatformRules({
    required this.captionLimit,
    this.hashtagCap,
    this.titleLimit,
    this.requiresMedia = false,
    required this.tip,
  });
}

const Map<String, PlatformRules> platformRules = {
  'instagram': PlatformRules(
    captionLimit: 2200,
    hashtagCap: 30,
    requiresMedia: true,
    tip: 'Links in captions are not clickable. Use link in bio.',
  ),
  'tiktok': PlatformRules(
    captionLimit: 2200,
    requiresMedia: true,
    tip: 'Keep it short. The video does the work.',
  ),
  'youtube': PlatformRules(
    captionLimit: 5000,
    titleLimit: 100,
    requiresMedia: true,
    tip: 'The first line becomes the title.',
  ),
  'facebook': PlatformRules(
    captionLimit: 63206,
    tip: 'Longer posts work here. Ask a question.',
  ),
  'linkedin': PlatformRules(
    captionLimit: 3000,
    tip: 'Line breaks make long posts easier to read.',
  ),
  'twitter': PlatformRules(
    captionLimit: 280,
    tip: 'Split longer ideas into a thread.',
  ),
};

final RegExp _hashtag = RegExp(r'#\w+');

int hashtagCount(String text) => _hashtag.allMatches(text).length;

/// Everything wrong with [caption] on [platform], in words the user can act on.
List<String> captionWarnings(String platform, String caption, {required bool hasMedia}) {
  final rules = platformRules[platform];
  if (rules == null) return const [];
  final name = platformsMap[platform]?.name ?? platform;
  final tags = hashtagCount(caption);
  final titleLength = caption.split('\n').first.length;
  return [
    if (caption.length > rules.captionLimit)
      '$name allows ${rules.captionLimit} characters. This is ${caption.length}.',
    if (rules.hashtagCap != null && tags > rules.hashtagCap!)
      '$name allows ${rules.hashtagCap} hashtags. This has $tags.',
    if (rules.titleLimit != null && titleLength > rules.titleLimit!)
      '$name titles allow ${rules.titleLimit} characters. The first line is $titleLength.',
    if (rules.requiresMedia && !hasMedia) '$name needs an image or video.',
  ];
}
