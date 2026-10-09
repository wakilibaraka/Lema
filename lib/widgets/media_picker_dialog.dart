import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/media_upload_service.dart';
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
  bool _isUploading = false;
  String _uploadStatus = '';
  List<UploadedMediaItem> _recentUploads = [];

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

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final list = await MediaUploadService.getRecentUploads();
    if (mounted) {
      setState(() {
        _recentUploads = list;
      });
    }
  }

  Future<void> _pickAndUpload() async {
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Selecting file...';
    });

    try {
      final item = await MediaUploadService.pickAndUploadMedia(
        onProgress: (status) {
          if (mounted) setState(() => _uploadStatus = status);
        },
      );

      if (item != null && mounted) {
        Navigator.of(context).pop(
          MediaPickerResult(
            pathOrUrl: item.url,
            isVideo: item.isVideo,
            name: item.name,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File upload error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '';
        });
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
          width: 580,
          margin: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 680),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E24) : Colors.white,
            borderRadius: BorderRadius.circular(AppleTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
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
                            'Add Media for Preview & Auto-Post',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upload real MP4/MOV videos, images, or choose brand samples',
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

              // Upload Action Area
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: AppleTheme.systemBlue,
                  borderRadius: BorderRadius.circular(AppleTheme.radiusMd),
                  onPressed: _isUploading ? null : _pickAndUpload,
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              _uploadStatus.isNotEmpty ? _uploadStatus : 'Processing file...',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.cloud_upload_fill, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Upload Custom Video or Photo (MP4, MOV, PNG, JPG)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),

              // Scrollable Sections
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recent Uploads Section (if any)
                      if (_recentUploads.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MY RECENT UPLOADS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            Text(
                              '${_recentUploads.length} items',
                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _recentUploads.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final u = _recentUploads[index];
                              final sizeMb = (u.sizeBytes / (1024 * 1024)).toStringAsFixed(1);
                              return InkWell(
                                onTap: () => Navigator.of(context).pop(
                                  MediaPickerResult(pathOrUrl: u.url, isVideo: u.isVideo, name: u.name),
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        u.isVideo ? CupertinoIcons.film_fill : CupertinoIcons.photo,
                                        size: 16,
                                        color: u.isVideo ? AppleTheme.systemPurple : AppleTheme.systemTeal,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          u.name,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '$sizeMb MB',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          await MediaUploadService.removeRecent(u.id);
                                          _loadRecents();
                                        },
                                        child: const Icon(CupertinoIcons.trash, size: 14, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Brand Samples
                      Text(
                        'EMMS DIGITAL MEDIA SAMPLES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._sampleMedia.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(item),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.photo_fill,
                                    size: 16,
                                    color: item.isVideo ? AppleTheme.systemPurple : AppleTheme.systemTeal,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_right, size: 14, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Direct URL Input
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OR PASTE MEDIA LINK / CDN URL',
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
