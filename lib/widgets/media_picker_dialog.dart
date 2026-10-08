import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/apple_theme.dart';

class MediaPickerResult {
  final String pathOrUrl;
  final bool isVideo;
  final String name;

  MediaPickerResult({
    required this.pathOrUrl,
    required this.isVideo,
    required this.name,
  });
}

class MediaPickerDialog extends StatefulWidget {
  const MediaPickerDialog({super.key});

  static Future<MediaPickerResult?> show(BuildContext context) {
    return showCupertinoModalPopup<MediaPickerResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const MediaPickerDialog(),
    );
  }

  @override
  State<MediaPickerDialog> createState() => _MediaPickerDialogState();
}

class _MediaPickerDialogState extends State<MediaPickerDialog> {
  final TextEditingController _urlController = TextEditingController();

  final List<MediaPickerResult> _sampleMedia = [
    MediaPickerResult(
      pathOrUrl: 'assets/samples/emms_storytelling_reel.mp4',
      isVideo: true,
      name: 'Storytelling Tailored for Business (Reel MP4)',
    ),
    MediaPickerResult(
      pathOrUrl: 'assets/samples/emms_story_features.mp4',
      isVideo: true,
      name: 'Selling Feelings vs Selling Product (Reel MP4)',
    ),
    MediaPickerResult(
      pathOrUrl: 'assets/samples/emms_post1_story30mins.png',
      isVideo: false,
      name: 'Story in 30 Mins Masterclass (Graphic PNG)',
    ),
    MediaPickerResult(
      pathOrUrl: 'assets/samples/emms_post2_understand.png',
      isVideo: false,
      name: 'Understand Before Selling Carousel (Graphic PNG)',
    ),
    MediaPickerResult(
      pathOrUrl: 'assets/samples/emms_post3_onesentence.png',
      isVideo: false,
      name: 'One Sentence Transformation (Graphic PNG)',
    ),
  ];

  Future<void> _pickLocalFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'avi', 'mkv', 'png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final path = file.path;
        if (path != null) {
          final ext = file.extension?.toLowerCase() ?? '';
          final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
          if (mounted) {
            Navigator.of(context).pop(
              MediaPickerResult(
                pathOrUrl: path,
                isVideo: isVideo,
                name: file.name,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File picker error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 540,
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(AppleTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppleTheme.systemBlue.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(CupertinoIcons.photo_on_rectangle, color: AppleTheme.systemBlue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Media for Preview',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pick real video/image file from device or select Emms sample',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 22),
                      color: isDark ? Colors.white38 : Colors.black26,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Pick from Local Device Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: AppleTheme.systemBlue,
                  borderRadius: BorderRadius.circular(AppleTheme.radiusMd),
                  onPressed: _pickLocalFile,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.folder_badge_plus, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Browse Device Media (MP4, MOV, PNG, JPG)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // Samples Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  'OR SELECT REAL EMMS DIGITAL MEDIA SAMPLES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _sampleMedia.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _sampleMedia[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(item),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: (item.isVideo ? AppleTheme.systemPurple : AppleTheme.systemTeal).withAlpha(35),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item.isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.photo_fill,
                                size: 16,
                                color: item.isVideo ? AppleTheme.systemPurple : AppleTheme.systemTeal,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Direct URL Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OR PASTE MEDIA URL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'https://example.com/video.mp4 or image.png',
                              filled: true,
                              fillColor: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: isDark ? Colors.white.withAlpha(35) : Colors.black.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          onPressed: () {
                            final text = _urlController.text.trim();
                            if (text.isNotEmpty) {
                              final isVid = text.endsWith('.mp4') || text.endsWith('.mov') || text.contains('video');
                              Navigator.of(context).pop(
                                MediaPickerResult(
                                  pathOrUrl: text,
                                  isVideo: isVid,
                                  name: text.split('/').last,
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Use URL',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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
