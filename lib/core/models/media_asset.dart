const String kindVideo = 'video';
const String kindImage = 'image';
const String kindAudio = 'audio';
const String kindGraphic = 'graphic';

class MediaAsset {
  final String id;
  final String url;
  final String name;
  final String kind; // 'video' | 'image' | 'audio' | 'graphic'
  final List<String> tags;
  final DateTime addedAt;

  const MediaAsset({
    required this.id,
    required this.url,
    required this.name,
    required this.kind,
    this.tags = const [],
    required this.addedAt,
  });

  bool get isVideo => kind == kindVideo;

  MediaAsset copyWith({List<String>? tags}) => MediaAsset(
        id: id,
        url: url,
        name: name,
        kind: kind,
        tags: tags ?? this.tags,
        addedAt: addedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'name': name,
        'kind': kind,
        'tags': tags,
        'addedAt': addedAt.toIso8601String(),
      };

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
        id: json['id'] as String,
        url: json['url'] as String,
        name: json['name'] as String? ?? '',
        kind: json['kind'] as String? ?? kindImage,
        tags: List<String>.from(json['tags'] ?? const <String>[]),
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime(2000),
      );
}

/// Splits what the user typed into clean tags: "Reel, #Promo, reel" -> reel, promo.
List<String> parseTags(String text) => text
    .split(',')
    .map((t) => t.trim().replaceFirst('#', '').toLowerCase())
    .where((t) => t.isNotEmpty)
    .toSet()
    .toList();

/// Assets carrying [tag] (when set) whose name or tags contain [query].
List<MediaAsset> filterAssets(List<MediaAsset> assets, {String? tag, String query = ''}) {
  final q = query.trim().toLowerCase();
  return assets
      .where((a) =>
          (tag == null || a.tags.contains(tag)) &&
          (q.isEmpty || a.name.toLowerCase().contains(q) || a.tags.any((t) => t.contains(q))))
      .toList();
}
