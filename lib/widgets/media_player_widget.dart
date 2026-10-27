import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'dart:io' show File;

import '../providers/app_provider.dart';
import '../theme/backdrop_theme.dart';

class UniversalMediaPlayer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;
  final BoxFit fit;
  final bool autoPlay;
  final bool showControls;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  /// Thumbnail treatment for small previews (grid tiles, queue cards, pickers):
  /// a small glass play badge instead of the 58pt playback overlay, and a
  /// compact failure state instead of the full "Video Preview Standby" card.
  ///
  /// A 58pt play circle covered most of a 3-column tile's artwork, and a
  /// failed decode painted an error card with a button inside a 78pt box.
  final bool thumbnail;

  const UniversalMediaPlayer({
    super.key,
    required this.mediaUrl,
    this.isVideo = false,
    this.fit = BoxFit.cover,
    this.autoPlay = true,
    this.showControls = true,
    this.width,
    this.height,
    this.onTap,
    this.thumbnail = false,
  });

  @override
  State<UniversalMediaPlayer> createState() => _UniversalMediaPlayerState();
}

class _UniversalMediaPlayerState extends State<UniversalMediaPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(UniversalMediaPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl ||
        oldWidget.isVideo != widget.isVideo) {
      _disposeController();
      if (widget.isVideo) {
        _initVideo();
      } else {
        setState(() {
          _isInitialized = false;
          _hasError = false;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initVideo() async {
    _disposeController();
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final url = widget.mediaUrl.trim();
      if (url.startsWith('assets/')) {
        _controller = VideoPlayerController.asset(url);
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else if (!kIsWeb &&
          (url.startsWith('/') ||
              url.contains(':\\') ||
              url.startsWith('file://'))) {
        final cleanPath = url.replaceFirst('file://', '');
        _controller = VideoPlayerController.file(File(cleanPath));
      } else {
        _controller = VideoPlayerController.asset(url);
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      // Slice 22: explicit autoPlay means *eligible*; the Settings toggle
      // has the final word (read without watching — initState-safe).
      if (widget.autoPlay && _autoplayAllowed()) {
        await _controller!.play();
      }
      _controller!.addListener(_onControllerUpdate);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  /// Slice 22: Settings toggle read without registering a dependency
  /// (initState-safe). Missing provider degrades to the old behavior.
  bool _autoplayAllowed() {
    try {
      return Provider.of<AppProvider>(context, listen: false).autoplayVideos;
    } catch (_) {
      return true;
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Slice 22: live-sync playback with the Settings toggle, so flipping it
    // stops (or starts) already-mounted videos on the next frame.
    if (widget.isVideo) {
      final shouldPlay =
          widget.autoPlay && context.watch<AppProvider>().autoplayVideos;
      if (_controller != null && _isInitialized && !_hasError) {
        final playing = _controller!.value.isPlaying;
        if (shouldPlay && !playing) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _controller?.play(),
          );
        } else if (!shouldPlay && playing) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _controller?.pause(),
          );
        }
      }
    }
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: Colors.black),
      child: widget.isVideo ? _buildVideoPlayer() : _buildImageViewer(),
    );
  }

  Widget _buildImageViewer() {
    final url = widget.mediaUrl.trim();
    Widget imageWidget;

    if (url.startsWith('assets/')) {
      imageWidget = Image.asset(
        url,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else if (url.startsWith('data:image')) {
      try {
        final base64String = url.contains(',') ? url.split(',').last : url;
        imageWidget = Image.memory(
          base64Decode(base64String),
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } catch (_) {
        imageWidget = _buildPlaceholder();
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = Image.network(
        url,
        fit: widget.fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CupertinoActivityIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else if (!kIsWeb &&
        (url.startsWith('/') ||
            url.contains(':\\') ||
            url.startsWith('file://'))) {
      final cleanPath = url.replaceFirst('file://', '');
      imageWidget = Image.file(
        File(cleanPath),
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      imageWidget = Image.asset(
        url,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    return GestureDetector(onTap: widget.onTap, child: imageWidget);
  }

  /// Compact, non-interactive stand-in for a thumbnail whose decode failed:
  /// no Retry button and no scrolling card, just the asset's identity.
  Widget _buildThumbnailFallback() {
    return Container(
      color: const Color(0xFF1C1C1E),
      // Scales down to whatever box it is given (48pt picker previews up to
      // 76pt queue cards) so a compact fallback can never overflow.
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.videocam_fill,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.mediaUrl.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Small glass play badge for thumbnails, per the design plan's tile rule
  /// (a badge, never a control that eats the artwork).
  Widget _buildPlayBadge() {
    return Positioned(
      // Top-left, clear of the tile's platform dots and timestamp strip;
      // sits just under the status pill.
      left: 7,
      top: 34,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              CupertinoIcons.play_fill,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (widget.thumbnail) {
      if (_hasError) return _buildThumbnailFallback();
      if (!_isInitialized || _controller == null) {
        return const Center(
          child: CupertinoActivityIndicator(color: Colors.white, radius: 10),
        );
      }
      return GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: widget.fit,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            ),
            if (!_controller!.value.isPlaying) _buildPlayBadge(),
          ],
        ),
      );
    }

    if (_hasError) {
      // Clipped, never scrollable: a failed decode must never overflow,
      // even inside a 78px grid tile. Large previews show the full card.
      return ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.play_rectangle,
                    color: Color(0xFFFF9500),
                    size: 40,
                    // Backdrop orange == iOS systemOrange; tracked for migration.

                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Video Preview Standby',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage.isNotEmpty
                        ? _errorMessage
                        : widget.mediaUrl.split('/').last,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _initVideo,
                    child: const Text(
                      'Retry Decode',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
      );
    }

    final isPlaying = _controller!.value.isPlaying;
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          _togglePlayPause();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video surface
          SizedBox.expand(
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),

          // Play/pause overlay when paused or hovered
          if (!isPlaying)
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                CupertinoIcons.play_fill,
                color: Colors.white,
                size: 28,
              ),
            ),

          // Bottom interactive overlay controls
          if (widget.showControls)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  // Play/Pause button
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPlaying
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Progress bar
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: duration.inMilliseconds > 0
                            ? (position.inMilliseconds /
                                      duration.inMilliseconds)
                                  .clamp(0.0, 1.0)
                            : 0.0,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          BackdropTheme.accent,
                        ),
                        // Backdrop magenta replaces iOS systemBlue here.

                        minHeight: 3.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Audio Mute/Unmute
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted
                            ? CupertinoIcons.volume_off
                            : CupertinoIcons.volume_up,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isVideo
                  ? CupertinoIcons.video_camera
                  : CupertinoIcons.photo,
              color: Colors.white.withValues(alpha: 0.4),
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              'Emms Media Asset',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
