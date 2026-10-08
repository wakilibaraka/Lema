import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';

class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  final List<TaskModel> _tasks = [
    TaskModel(
      id: 't1',
      title: 'Verify Morning Peak Queue Dispatch (09:00 AM)',
      description: 'Check daemon sync on Instagram Reels and TikTok auto-poster.',
      isCompleted: true,
      priority: TaskPriority.high,
      dueDate: DateTime.now(),
    ),
    TaskModel(
      id: 't2',
      title: 'Engage with First 15 Comments on Emms Storytelling Reel',
      description: 'Reply to comments within first 60 minutes to trigger algorithm reach.',
      isCompleted: true,
      priority: TaskPriority.high,
      dueDate: DateTime.now(),
    ),
    TaskModel(
      id: 't3',
      title: 'Record 60s "Selling Feelings vs Features" Reel',
      description: 'Use the 3-second hook teleprompter in Hooks Pipeline.',
      isCompleted: false,
      priority: TaskPriority.urgent,
      dueDate: DateTime.now(),
    ),
    TaskModel(
      id: 't4',
      title: 'Generate Next Week’s 7-Day Batch in AI Studio',
      description: 'Review and queue Gemini suggestions for Mon-Sun calendar.',
      isCompleted: false,
      priority: TaskPriority.medium,
      dueDate: DateTime.now().add(const Duration(days: 1)),
    ),
    TaskModel(
      id: 't5',
      title: 'Inspect Device Simulator Mockup for Facebook Feed',
      description: 'Ensure link previews and thumbnail aspect ratio are pixel-perfect.',
      isCompleted: false,
      priority: TaskPriority.low,
      dueDate: DateTime.now().add(const Duration(days: 2)),
    ),
  ];

  final TextEditingController _taskController = TextEditingController();

  void _toggleTask(String id) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _tasks[index];
        _tasks[index] = task.copyWith(isCompleted: !task.isCompleted);
      }
    });
  }

  void _addTask() {
    final text = _taskController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.insert(
        0,
        TaskModel(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}',
          title: text,
          description: 'Added from quick daily operational tick checklist.',
          isCompleted: false,
          priority: TaskPriority.medium,
          dueDate: DateTime.now(),
        ),
      );
      _taskController.clear();
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedCount = _tasks.where((t) => t.isCompleted).length;
    final progress = _tasks.isNotEmpty ? completedCount / _tasks.length : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Operations Tick',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actionable daily growth checklist for creators, agencies, and brand managers.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Daily Progress Tracker Card
            AppleGlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppleTheme.systemGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.checkmark_seal_fill, color: AppleTheme.systemGreen, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daily Execution Progress',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              '$completedCount / ${_tasks.length} Completed (${(progress * 100).toInt()}%)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppleTheme.systemGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppleTheme.systemGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Add Quick Task Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    onSubmitted: (_) => _addTask(),
                    decoration: InputDecoration(
                      hintText: 'Add a new operational task or tick item...',
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: _addTask,
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.add, size: 16),
                      SizedBox(width: 6),
                      Text('Add Task', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Checklist
            Expanded(
              child: ListView.separated(
                itemCount: _tasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final isDone = task.isCompleted;

                  return AppleGlassCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => _toggleTask(task.id),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Checkbox
                        GestureDetector(
                          onTap: () => _toggleTask(task.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isDone ? AppleTheme.systemGreen : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: isDone ? AppleTheme.systemGreen : (isDark ? Colors.white38 : Colors.black26),
                                width: 2,
                              ),
                            ),
                            child: isDone
                                ? const Icon(CupertinoIcons.checkmark, size: 15, color: Colors.white)
                                : null,
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Title & Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDone
                                      ? (isDark ? Colors.white38 : Colors.black38)
                                      : (isDark ? Colors.white : Colors.black),
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  task.description,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Priority Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: _priorityColor(task.priority).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            task.priorityName.toUpperCase(),
                            style: TextStyle(
                              color: _priorityColor(task.priority),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(CupertinoIcons.trash, size: 16),
                          color: isDark ? Colors.white30 : Colors.black26,
                          onPressed: () {
                            setState(() => _tasks.removeAt(index));
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return AppleTheme.systemRed;
      case TaskPriority.high:
        return AppleTheme.systemOrange;
      case TaskPriority.medium:
        return AppleTheme.systemBlue;
      case TaskPriority.low:
        return AppleTheme.systemTeal;
    }
  }
}
