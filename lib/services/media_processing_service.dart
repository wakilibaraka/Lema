enum MediaValidationResult {
  valid,
  fileTooLarge,
  unsupportedFormat,
  dimensionsInvalid,
  codecInvalid,
  fileNotFound,
}

class MediaValidationIssue {
  final MediaValidationResult result;
  final String message;
  final String? suggestion;

  const MediaValidationIssue({
    required this.result,
    required this.message,
    this.suggestion,
  });

  bool get isValid => result == MediaValidationResult.valid;
}

class PlatformMediaConstraints {
  final String platform;
  final int maxFileSizeMB;
  final List<String> allowedFormats;
  final int? minWidth;
  final int? maxWidth;
  final int? minHeight;
  final int? maxHeight;
  final List<String> requiredCodecs;

  const PlatformMediaConstraints({
    required this.platform,
    required this.maxFileSizeMB,
    required this.allowedFormats,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    required this.requiredCodecs,
  });
}

class MediaProcessingService {
  static const int _maxImageSizeMB = 8;
  static const int _maxVideoSizeMB = 250;

  static const Map<String, PlatformMediaConstraints> platformConstraints = {
    'instagram': PlatformMediaConstraints(
      platform: 'Instagram',
      maxFileSizeMB: 250,
      allowedFormats: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
      minWidth: 1080,
      maxWidth: 1080,
      minHeight: 1080,
      maxHeight: 1920,
      requiredCodecs: ['h264', 'h265'],
    ),
    'tiktok': PlatformMediaConstraints(
      platform: 'TikTok',
      maxFileSizeMB: 250,
      allowedFormats: ['mp4', 'webm'],
      minWidth: 1080,
      maxWidth: 1080,
      minHeight: 1920,
      maxHeight: 1920,
      requiredCodecs: ['h264'],
    ),
    'youtube': PlatformMediaConstraints(
      platform: 'YouTube',
      maxFileSizeMB: 256,
      allowedFormats: ['mp4', 'mov', 'avi', 'webm', 'mkv'],
      minWidth: 426,
      maxWidth: 7680,
      minHeight: 240,
      maxHeight: 4320,
      requiredCodecs: ['h264', 'h265', 'vp9'],
    ),
    'facebook': PlatformMediaConstraints(
      platform: 'Facebook',
      maxFileSizeMB: 250,
      allowedFormats: ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'gif'],
      requiredCodecs: ['h264'],
    ),
  };

  static MediaValidationIssue? validateMediaForPlatform({
    required String filePath,
    required String platform,
    required bool isVideo,
    int? fileSizeBytes,
  }) {
    final ext = filePath.split('.').last.toLowerCase();
    final constraints = platformConstraints[platform];
    if (constraints == null) return null;

    if (!constraints.allowedFormats.contains(ext)) {
      return MediaValidationIssue(
        result: MediaValidationResult.unsupportedFormat,
        message: '.$ext is not supported on ${constraints.platform}. Use: ${constraints.allowedFormats.join(', ')}',
        suggestion: 'Convert to ${constraints.allowedFormats.first.toUpperCase()} and try again.',
      );
    }

    final maxSize = isVideo
        ? _maxVideoSizeMB
        : _maxImageSizeMB;

    if (fileSizeBytes != null) {
      final sizeMB = fileSizeBytes / (1024 * 1024);
      if (sizeMB > maxSize) {
        return MediaValidationIssue(
          result: MediaValidationResult.fileTooLarge,
          message: 'File size ${sizeMB.toStringAsFixed(1)}MB exceeds ${maxSize}MB limit.',
          suggestion: 'Compress the file or export at a lower bitrate.',
        );
      }
    }

    if (isVideo && constraints.minWidth != null) {
      return MediaValidationIssue(
        result: MediaValidationResult.valid,
        message: 'Video format accepted. Ensure 1080x1920 resolution and H.264 codec for best results.',
      );
    }

    return null;
  }

  static List<MediaValidationIssue> validateMediaForAllPlatforms({
    required String filePath,
    required List<String> platforms,
    required bool isVideo,
    int? fileSizeBytes,
  }) {
    final issues = <MediaValidationIssue>[];
    for (final platform in platforms) {
      final issue = validateMediaForPlatform(
        filePath: filePath,
        platform: platform,
        isVideo: isVideo,
        fileSizeBytes: fileSizeBytes,
      );
      if (issue != null && !issue.isValid) {
        issues.add(issue);
      }
    }
    return issues;
  }

  static String getPlatformConstraintSummary(String platform) {
    final c = platformConstraints[platform];
    if (c == null) return '';
    final parts = <String>['Max ${c.maxFileSizeMB}MB'];
    if (c.allowedFormats.isNotEmpty) {
      parts.add(c.allowedFormats.map((f) => f.toUpperCase()).join('/'));
    }
    if (c.minWidth != null && c.minHeight != null) {
      parts.add('${c.minWidth}x${c.minHeight}+');
    }
    return parts.join(' · ');
  }

  static bool isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'webm', 'avi', 'mkv'].contains(ext);
  }

  static bool isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext);
  }
}
