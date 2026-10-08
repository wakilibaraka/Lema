enum TaskPriority { urgent, high, medium, low }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime dueDate;

  const TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.category = 'Operations',
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    required this.dueDate,
  });

  // Backward compatibility getters
  String get text => title;
  bool get completed => isCompleted;
  String get due => dueDate.toIso8601String().split('T').first;
  String get priorityName => priority.name;

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? dueDate,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'priority': priority.name,
        'isCompleted': isCompleted,
        'dueDate': dueDate.toIso8601String(),
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    TaskPriority parsedPriority = TaskPriority.medium;
    final prioStr = json['priority'] as String? ?? 'medium';
    for (final p in TaskPriority.values) {
      if (p.name == prioStr) {
        parsedPriority = p;
        break;
      }
    }

    return TaskModel(
      id: json['id'] as String? ?? 'task-${DateTime.now().millisecondsSinceEpoch}',
      title: (json['title'] ?? json['text'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      category: (json['category'] as String?) ?? 'Operations',
      priority: parsedPriority,
      isCompleted: (json['isCompleted'] ?? json['completed'] ?? false) as bool,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

final List<TaskModel> defaultTasksList = [
  TaskModel(
    id: 'task-1',
    title: 'Verify Morning Peak Queue Dispatch (09:00 AM)',
    description: 'Check daemon sync on Instagram Reels and TikTok auto-poster.',
    category: 'Operations',
    priority: TaskPriority.high,
    isCompleted: true,
    dueDate: DateTime.now(),
  ),
  TaskModel(
    id: 'task-2',
    title: 'Engage with First 15 Comments on Emms Storytelling Reel',
    description: 'Reply to comments within first 60 minutes to trigger algorithm reach.',
    category: 'Engagement',
    priority: TaskPriority.high,
    isCompleted: true,
    dueDate: DateTime.now(),
  ),
  TaskModel(
    id: 'task-3',
    title: 'Record 60s "Selling Feelings vs Features" Reel',
    description: 'Use the 3-second hook teleprompter in Hooks Pipeline.',
    category: 'Creation',
    priority: TaskPriority.urgent,
    isCompleted: false,
    dueDate: DateTime.now(),
  ),
  TaskModel(
    id: 'task-4',
    title: 'Generate Next Week’s 7-Day Batch in AI Studio',
    description: 'Review and queue Gemini suggestions for Mon-Sun calendar.',
    category: 'Planning',
    priority: TaskPriority.medium,
    isCompleted: false,
    dueDate: DateTime.now().add(const Duration(days: 1)),
  ),
  TaskModel(
    id: 'task-5',
    title: 'Inspect Device Simulator Mockup for Facebook Feed',
    description: 'Ensure link previews and thumbnail aspect ratio are pixel-perfect.',
    category: 'QA',
    priority: TaskPriority.low,
    isCompleted: false,
    dueDate: DateTime.now().add(const Duration(days: 2)),
  ),
];
