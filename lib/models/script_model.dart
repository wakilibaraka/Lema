enum ScriptStage { draft, readyToRecord, recorded, published }

class ScriptModel {
  final String id;
  final String lessonId;
  final String title;
  final String targetLength;
  final ScriptStage stage;
  final String hook;
  final String visualCue;
  final String problem;
  final String secret;
  final String hack;
  final String cta;
  final String mediaAsset;

  const ScriptModel({
    required this.id,
    this.lessonId = 'emms-story',
    required this.title,
    this.targetLength = '60s',
    this.stage = ScriptStage.readyToRecord,
    required this.hook,
    this.visualCue = 'Direct to camera with energetic delivery',
    required this.problem,
    this.secret = 'Storytelling converts 22x better than raw facts',
    String? hack,
    String? solution,
    required this.cta,
    this.mediaAsset = 'assets/samples/emms_storytelling_reel.mp4',
  }) : hack = hack ?? solution ?? '';

  String get solution => hack;

  String get stageName {
    switch (stage) {
      case ScriptStage.draft:
        return 'Draft Concept';
      case ScriptStage.readyToRecord:
        return 'Ready to Film';
      case ScriptStage.recorded:
        return 'Recorded & Edited';
      case ScriptStage.published:
        return 'Published / Queued';
    }
  }

  ScriptModel copyWith({
    String? id,
    String? lessonId,
    String? title,
    String? targetLength,
    ScriptStage? stage,
    String? hook,
    String? visualCue,
    String? problem,
    String? secret,
    String? hack,
    String? cta,
    String? mediaAsset,
  }) {
    return ScriptModel(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      targetLength: targetLength ?? this.targetLength,
      stage: stage ?? this.stage,
      hook: hook ?? this.hook,
      visualCue: visualCue ?? this.visualCue,
      problem: problem ?? this.problem,
      secret: secret ?? this.secret,
      hack: hack ?? this.hack,
      cta: cta ?? this.cta,
      mediaAsset: mediaAsset ?? this.mediaAsset,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lessonId': lessonId,
        'title': title,
        'targetLength': targetLength,
        'stage': stage.name,
        'hook': hook,
        'visualCue': visualCue,
        'problem': problem,
        'secret': secret,
        'hack': hack,
        'cta': cta,
        'mediaAsset': mediaAsset,
      };

  factory ScriptModel.fromJson(Map<String, dynamic> json) {
    ScriptStage parsedStage = ScriptStage.readyToRecord;
    final stageStr = json['stage'] as String? ?? 'readyToRecord';
    for (final s in ScriptStage.values) {
      if (s.name == stageStr) {
        parsedStage = s;
        break;
      }
    }

    return ScriptModel(
      id: json['id'] as String? ?? 'script-${DateTime.now().millisecondsSinceEpoch}',
      lessonId: json['lessonId'] as String? ?? 'emms-story',
      title: json['title'] as String? ?? '',
      targetLength: json['targetLength'] as String? ?? '60s',
      stage: parsedStage,
      hook: json['hook'] as String? ?? '',
      visualCue: json['visualCue'] as String? ?? '',
      problem: json['problem'] as String? ?? '',
      secret: json['secret'] as String? ?? '',
      hack: json['hack'] as String? ?? json['solution'] as String? ?? '',
      cta: json['cta'] as String? ?? '',
      mediaAsset: json['mediaAsset'] as String? ?? 'assets/samples/emms_storytelling_reel.mp4',
    );
  }
}
