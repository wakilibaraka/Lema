class QueueSlotModel {
  final String id;
  final String time; // e.g. "09:00"
  final String label;

  const QueueSlotModel({
    required this.id,
    required this.time,
    required this.label,
  });

  String get name => label;
  String get formattedTime => time;
  bool get isActive => true;

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'label': label,
      };

  factory QueueSlotModel.fromJson(Map<String, dynamic> json) {
    return QueueSlotModel(
      id: json['id'] as String? ?? 'slot-${DateTime.now().millisecondsSinceEpoch}',
      time: json['time'] as String? ?? '09:00',
      label: json['label'] as String? ?? 'Custom Slot',
    );
  }
}
