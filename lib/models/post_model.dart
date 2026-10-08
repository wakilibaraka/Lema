import 'platform_info.dart';

enum PostStatus { scheduled, published, draft, failed }

class PostModel {
  final String id;
  final String title;
  final String hook;
  final String caption;
  final List<String> platforms;
  final String mediaType; // 'video' | 'image'
  final String mediaUrl;
  final String? localFilePath;
  final String scheduledDate; // 'YYYY-MM-DD'
  final dynamic _scheduledTimeRaw; // String 'HH:MM' or DateTime
  final String status; // 'scheduled' | 'published' | 'draft' | 'failed'
  final String views;
  final String likes;
  final int comments;
  final DateTime? createdAt;
  final DateTime? postedAt;

  PostModel({
    required this.id,
    String? title,
    String? hook,
    required this.caption,
    List<String>? platforms,
    SocialPlatform? platform,
    String? mediaType,
    bool? isVideo,
    required this.mediaUrl,
    this.localFilePath,
    String? scheduledDate,
    dynamic scheduledTime,
    this.status = 'scheduled',
    this.views = '1420',
    dynamic likes = '2818',
    this.comments = 142,
    this.createdAt,
    this.postedAt,
  })  : title = title ?? (caption.length > 30 ? caption.substring(0, 30) : caption),
        hook = hook ?? (caption.length > 45 ? caption.substring(0, 45) : caption),
        platforms = platforms ?? [platform != null ? platform.name : 'instagram'],
        mediaType = mediaType ?? ((isVideo == true || mediaUrl.toLowerCase().endsWith('.mp4') || mediaUrl.toLowerCase().endsWith('.mov')) ? 'video' : 'image'),
        scheduledDate = scheduledDate ?? (scheduledTime is DateTime ? scheduledTime.toIso8601String().split('T').first : '2026-10-12'),
        _scheduledTimeRaw = scheduledTime ?? '18:00',
        likes = likes.toString();

  bool get isVideo =>
      mediaType == 'video' ||
      mediaUrl.toLowerCase().endsWith('.mp4') ||
      mediaUrl.toLowerCase().contains('.mp4?') ||
      mediaUrl.toLowerCase().endsWith('.mov') ||
      mediaUrl.toLowerCase().endsWith('.webm');

  PlatformInfo get platformInfo {
    if (platforms.isNotEmpty) {
      final key = platforms.first.toLowerCase();
      return platformsMap[key] ?? platformsMap['instagram']!;
    }
    return platformsMap['instagram']!;
  }

  SocialPlatform get primaryPlatform {
    if (platforms.isNotEmpty) {
      final key = platforms.first.toLowerCase();
      for (final p in SocialPlatform.values) {
        if (p.name == key) return p;
      }
    }
    return SocialPlatform.instagram;
  }

  DateTime get scheduledTime {
    if (_scheduledTimeRaw is DateTime) {
      return _scheduledTimeRaw as DateTime;
    }
    if (_scheduledTimeRaw is String) {
      try {
        final timeParts = (_scheduledTimeRaw as String).split(':');
        final dateParts = scheduledDate.split('-');
        if (dateParts.length == 3 && timeParts.length >= 2) {
          return DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        }
      } catch (_) {}
    }
    return DateTime.now().add(const Duration(hours: 3));
  }

  PostStatus get postStatus {
    switch (status.toLowerCase()) {
      case 'published':
      case 'posted':
        return PostStatus.published;
      case 'failed':
        return PostStatus.failed;
      case 'draft':
        return PostStatus.draft;
      case 'scheduled':
      default:
        return PostStatus.scheduled;
    }
  }

  int get likesCount {
    return int.tryParse(likes.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  PostModel copyWith({
    String? id,
    String? title,
    String? hook,
    String? caption,
    List<String>? platforms,
    String? mediaType,
    String? mediaUrl,
    String? localFilePath,
    String? scheduledDate,
    dynamic scheduledTime,
    String? status,
    String? views,
    String? likes,
    int? comments,
    DateTime? createdAt,
    DateTime? postedAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      hook: hook ?? this.hook,
      caption: caption ?? this.caption,
      platforms: platforms ?? this.platforms,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      localFilePath: localFilePath ?? this.localFilePath,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this._scheduledTimeRaw,
      status: status ?? this.status,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      postedAt: postedAt ?? this.postedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hook': hook,
        'caption': caption,
        'platforms': platforms,
        'mediaType': mediaType,
        'mediaUrl': mediaUrl,
        'localFilePath': localFilePath,
        'scheduledDate': scheduledDate,
        'scheduledTime': scheduledTime.toIso8601String(),
        'status': status,
        'views': views,
        'likes': likes,
        'comments': comments,
        'createdAt': createdAt?.toIso8601String(),
        'postedAt': postedAt?.toIso8601String(),
      };

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String? ?? 'post-${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? '',
      hook: json['hook'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      platforms: List<String>.from(json['platforms'] ?? ['instagram']),
      mediaType: json['mediaType'] as String? ?? 'image',
      mediaUrl: json['mediaUrl'] as String? ?? '',
      localFilePath: json['localFilePath'] as String?,
      scheduledDate: json['scheduledDate'] as String? ?? '2026-10-12',
      scheduledTime: json['scheduledTime'] ?? '18:00',
      status: json['status'] as String? ?? 'scheduled',
      views: json['views']?.toString() ?? '1420',
      likes: json['likes']?.toString() ?? '2818',
      comments: json['comments'] != null ? (json['comments'] as num).toInt() : 142,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      postedAt: json['postedAt'] != null ? DateTime.tryParse(json['postedAt'] as String) : null,
    );
  }
}

/// Seeded posts directly extracted from Emms Digital Media dataset
final List<PostModel> defaultSeedPosts = [
  PostModel(
    id: 'post-1',
    title: 'The Power of Storytelling (The Art of Selling)',
    hook: 'The Power of Storytelling — why the biggest brands never sell their product, they sell the emotion.',
    caption:
        'The Power of Storytelling ✨\n\nFacts tell, but stories sell. If you want customers to remember your brand and take action, take them on an emotional journey.\n\nDM "STORY" to audit your video hooks! 🎬\n\n#storytellingforbusiness #storytelling #theartofselling #content #contentcreator #emmsdigitalmedia',
    platforms: ['instagram', 'tiktok'],
    mediaType: 'video',
    mediaUrl: 'assets/samples/emms_storytelling_reel.mp4',
    scheduledDate: '2026-10-12',
    scheduledTime: DateTime.now().add(const Duration(hours: 1)),
    status: 'scheduled',
    views: '84.2K',
    likes: '2818',
    comments: 142,
  ),
  PostModel(
    id: 'post-2',
    title: 'Selling Feelings vs Selling Product',
    hook: 'People do not buy cameras for resolution. They buy the way memories feel.',
    caption:
        'Stop blending in. Selling feelings vs selling product features. Tailored storytelling reels designed for real customer action.\n\n🎬 Stop blending in. Start standing out.\n📞 Contact me: 0757 638 846\n📧 emmahsonny@gmail.com\n\n#reels #storytelling #businessgrowth #nairobi',
    platforms: ['instagram', 'facebook'],
    mediaType: 'video',
    mediaUrl: 'assets/samples/emms_story_features.mp4',
    scheduledDate: '2026-10-12',
    scheduledTime: DateTime.now().add(const Duration(hours: 4)),
    status: 'scheduled',
    views: '45.1K',
    likes: '1430',
    comments: 88,
  ),
  PostModel(
    id: 'post-3',
    title: 'Framework: Crafting a Story in 30 Mins',
    hook: 'How to structure your client case study before dinner tonight.',
    caption:
        'How to write a viral storytelling reel in under 30 minutes without writer block.\n\n1. The Hook (3 seconds)\n2. The Tension (15 seconds)\n3. The Transformation (30 seconds)\n4. The CTA (10 seconds)\n\nSave this framework for your next shoot! 📌\n\n#videomarketing #kenyancreators #contentproduction #emmsdigitalmedia',
    platforms: ['instagram', 'linkedin'],
    mediaType: 'image',
    mediaUrl: 'assets/samples/emms_post1_story30mins.png',
    scheduledDate: '2026-10-13',
    scheduledTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    status: 'scheduled',
    views: '12.8K',
    likes: '842',
    comments: 54,
  ),
  PostModel(
    id: 'post-4',
    title: 'Understand Before Selling Carousel',
    hook: 'If you do not know their breaking point, your offer is irrelevant.',
    caption:
        'Understand first, sell later. The cornerstone principle of high-converting visual storytelling.\n\nSwipe through for the breakdown 👉\n\n#contentstrategy #thecontentdoctor #brandstorytelling',
    platforms: ['instagram'],
    mediaType: 'image',
    mediaUrl: 'assets/samples/emms_post2_understand.png',
    scheduledDate: '2026-10-13',
    scheduledTime: DateTime.now().add(const Duration(days: 1, hours: 6)),
    status: 'scheduled',
    views: '19.4K',
    likes: '912',
    comments: 67,
  ),
  PostModel(
    id: 'post-5',
    title: 'One-Sentence Pitch Masterclass',
    hook: 'Can you describe what you do in one sentence? If not, read this.',
    caption:
        'The One-Sentence Transformation Pitch. If a 10-year-old cannot understand your business value in one sentence, prospects will not convert.\n\nDrop your pitch below and I will critique the first 20! 👇\n\n#copywriting #storytelling #videoreels #emmsdigitalmedia',
    platforms: ['instagram', 'tiktok', 'twitter'],
    mediaType: 'image',
    mediaUrl: 'assets/samples/emms_post3_onesentence.png',
    scheduledDate: '2026-10-14',
    scheduledTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
    status: 'scheduled',
    views: '32.0K',
    likes: '1540',
    comments: 112,
  ),
];
