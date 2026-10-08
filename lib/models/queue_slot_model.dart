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

const List<QueueSlotModel> defaultQueueSlots = [
  QueueSlotModel(id: 'slot-1', time: '09:00 AM', label: 'Morning Peak'),
  QueueSlotModel(id: 'slot-2', time: '01:15 PM', label: 'Lunch Break'),
  QueueSlotModel(id: 'slot-3', time: '06:30 PM', label: 'Evening Prime'),
  QueueSlotModel(id: 'slot-4', time: '09:45 PM', label: 'Late Night Scroll'),
];
