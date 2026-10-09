import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UploadedMediaItem {
  final String id;
  final String name;
  final String url;
  final bool isVideo;
  final int sizeBytes;
  final DateTime uploadedAt;

  UploadedMediaItem({
    required this.id,
    required this.name,
    required this.url,
    required this.isVideo,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'isVideo': isVideo,
    'sizeBytes': sizeBytes,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory UploadedMediaItem.fromJson(Map<String, dynamic> json) => UploadedMediaItem(
    id: json['id'] as String? ?? 'id_${DateTime.now().millisecondsSinceEpoch}',
    name: json['name'] as String? ?? 'Uploaded Media',
    url: json['url'] as String? ?? '',
    isVideo: json['isVideo'] as bool? ?? false,
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    uploadedAt: json['uploadedAt'] != null
        ? DateTime.tryParse(json['uploadedAt']) ?? DateTime.now()
        : DateTime.now(),
  );
}

class MediaUploadService {
  static const String _storageKey = 'lema_uploaded_media_items';
  static const String _daemonUploadUrl = 'http://localhost:3001/api/upload';

  /// Pick a file (video or image) from the local device/computer.
  /// Works across Web, macOS, Windows, Linux, iOS, and Android.
  static Future<UploadedMediaItem?> pickAndUploadMedia({
    Function(String status)? onProgress,
  }) async {
    try {
      onProgress?.call('Selecting file...');
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mov', 'webm', 'avi', 'mkv', 'png', 'jpg', 'jpeg', 'webp', 'gif'],
      );

      if (files.isEmpty) {
        return null;
      }

      final file = files.first;
      final fileName = file.name;
      final ext = file.extension?.toLowerCase() ?? '';
      final isVideo = ['mp4', 'mov', 'webm', 'avi', 'mkv'].contains(ext);
      final bytes = await file.readAsBytes();
      final sizeBytes = file.lengthSync() ?? (await file.length()) ?? bytes.length;

      String finalUrl = '';

      // Try uploading to local daemon backend (Port 3001) if bytes are available
      if (bytes.isNotEmpty) {
        onProgress?.call('Uploading to daemon server...');
        try {
          final base64Data = base64Encode(bytes);
          final mime = isVideo ? 'video/$ext' : 'image/$ext';
          final payload = jsonEncode({
            'name': fileName,
            'type': mime,
            'data': 'data:$mime;base64,$base64Data',
          });

          final response = await http.post(
            Uri.parse(_daemonUploadUrl),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = jsonDecode(response.body);
            if (data['fileUrl'] != null) {
              finalUrl = 'http://localhost:3001${data['fileUrl']}';
            }
          }
        } catch (_) {
          // Daemon might be offline or slow, proceed to local fallback
        }
      }

      // If backend upload was not used or failed:
      if (finalUrl.isEmpty) {
        if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
          finalUrl = file.path!;
        } else if (bytes.isNotEmpty) {
          // Web fallback: use base64 data URI
          final mime = isVideo ? 'video/mp4' : 'image/png';
          finalUrl = 'data:$mime;base64,${base64Encode(bytes)}';
        }
      }

      if (finalUrl.isEmpty) {
        throw Exception('Unable to obtain media location or data.');
      }

      final item = UploadedMediaItem(
        id: 'upload_${DateTime.now().millisecondsSinceEpoch}',
        name: fileName,
        url: finalUrl,
        isVideo: isVideo,
        sizeBytes: sizeBytes,
        uploadedAt: DateTime.now(),
      );

      await saveToRecents(item);
      return item;
    } catch (e) {
      debugPrint('MediaUploadService error: $e');
      rethrow;
    }
  }

  /// Persist uploaded media item into SharedPreferences
  static Future<void> saveToRecents(UploadedMediaItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getRecentUploads();
      items.removeWhere((i) => i.name == item.name || i.url == item.url);
      items.insert(0, item);
      if (items.length > 20) items.removeLast();

      final jsonList = items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving recent media: $e');
    }
  }

  /// Retrieve list of recent uploads
  static Future<List<UploadedMediaItem>> getRecentUploads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => UploadedMediaItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading recent media: $e');
      return [];
    }
  }

  /// Remove item from recents
  static Future<void> removeRecent(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getRecentUploads();
      items.removeWhere((i) => i.id == id);
      final jsonList = items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error removing recent media: $e');
    }
  }
}
