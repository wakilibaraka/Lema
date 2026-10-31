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
  final String _scheduledDateRaw; // 'YYYY-MM-DD'
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
        _scheduledDateRaw = scheduledDate ??
            (scheduledTime is DateTime
                ? scheduledTime.toIso8601String().split('T').first
                : '2026-10-12'),
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

  /// True when a scheduled post's time has already passed and nothing has
  /// published it. The daemon is parked, so nothing converts these
  /// automatically — the UI has to surface them.
  bool get isOverdue => status == 'scheduled' && scheduledTime.isBefore(DateTime.now());

  /// The calendar day the post belongs to.
  /// When the schedule is held as a real `DateTime` the day is derived from
  /// it, so `copyWith(scheduledTime: ...)` can never leave the two halves of
  /// the date/time pair disagreeing. Legacy "HH:MM" payloads keep the
  /// explicit day.
  String get scheduledDate {
    final raw = _scheduledTimeRaw;
    if (raw is DateTime) {
      return '${raw.year.toString().padLeft(4, '0')}-'
          '${raw.month.toString().padLeft(2, '0')}-'
          '${raw.day.toString().padLeft(2, '0')}';
    }
    return _scheduledDateRaw;
  }

  DateTime get scheduledTime {
    final raw = _scheduledTimeRaw;
    if (raw is DateTime) return raw;

    if (raw is String && raw.isNotEmpty) {
      // toJson writes a full ISO-8601 stamp, so try that first. Parsing it
      // as "HH:MM" used to throw, and a bare catch fell through to
      // "now + 3h" — which silently rebased every persisted post on each
      // app restart.
      final iso = DateTime.tryParse(raw);
      if (iso != null) return iso;

      // Legacy payload: "HH:MM" paired with scheduledDate "YYYY-MM-DD".
      final fromParts = _atTimeOfDay(raw, scheduledDate);
      if (fromParts != null) return fromParts;
    }

    // Unreadable payload: fall back to the documented default slot on the
    // stored date, never to a fresh "now" — otherwise corrupt data would
    // look like a legitimate reschedule. If even the date is garbage, a
    // fixed past instant keeps the value stable across calls (a
    // read-the-clock fallback would flip the post to overdue between two
    // rebuilds) and surfaces it in the overdue list instead of hiding it.
    return _dateOnly(_scheduledDateRaw) ?? DateTime(2000);
  }

  static DateTime? _dateOnly(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static DateTime? _atTimeOfDay(String hhmm, String date) {
    final time = hhmm.split(':');
    if (time.length < 2) return null;
    final h = int.tryParse(time[0]);
    final min = int.tryParse(time[1]);
    if (h == null || min == null) return null;
    final day = _dateOnly(date);
    if (day == null) return null;
    return DateTime(day.year, day.month, day.day, h, min);
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
      scheduledTime: scheduledTime ?? _scheduledTimeRaw,
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
