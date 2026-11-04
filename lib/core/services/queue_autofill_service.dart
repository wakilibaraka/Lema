import 'package:intl/intl.dart';

import '../models/post_model.dart';
import '../models/queue_slot_model.dart';

class QueueAutofillService {
  static List<DateTime> findGapsInRange({
    required DateTime start,
    required DateTime end,
    required List<PostModel> scheduledPosts,
    int minGapDays = 1,
  }) {
    final gaps = <DateTime>[];
    final scheduledDates = scheduledPosts
        .map((p) => DateTime(p.scheduledTime.year, p.scheduledTime.month, p.scheduledTime.day))
        .toSet();

    // Calendar arithmetic: adding 24h repeats a day when the clocks go back.
    for (var day = start;
        day.isBefore(end) || day.isAtSameMomentAs(end);
        day = DateTime(day.year, day.month, day.day + 1, day.hour, day.minute)) {
      final dayOnly = DateTime(day.year, day.month, day.day);
      if (!scheduledDates.contains(dayOnly)) {
        gaps.add(dayOnly);
      }
    }
    return gaps;
  }

  /// Up to [count] future times, one per day with nothing scheduled. Each uses
  /// the best of [rankedHours], or [fallbackSlots] when there is no history.
  static List<DateTime> openSlotTimes({
    required DateTime now,
    required int count,
    required List<PostModel> scheduledPosts,
    required List<int> rankedHours,
    required List<QueueSlotModel> fallbackSlots,
    int horizonDays = 30,
  }) {
    final minutes = rankedHours.isNotEmpty
        ? rankedHours.map((h) => h * 60).toList()
        : fallbackSlots.map((s) {
            final t = DateFormat('hh:mm a', 'en_US').parse(s.time);
            return t.hour * 60 + t.minute;
          }).toList();
    final gaps = findGapsInRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day + horizonDays),
      scheduledPosts: scheduledPosts,
    );
    final times = <DateTime>[];
    for (final gap in gaps) {
      if (times.length == count) break;
      for (final m in minutes) {
        final t = DateTime(gap.year, gap.month, gap.day, 0, m);
        if (t.isAfter(now)) {
          times.add(t);
          break;
        }
      }
    }
    return times;
  }

  static List<QueueSlotModel> suggestSlotsForGaps({
    required List<DateTime> gaps,
    required List<QueueSlotModel> existingSlots,
  }) {
    final suggestions = <QueueSlotModel>[];
    for (final gap in gaps) {
      for (final slot in existingSlots) {
        suggestions.add(QueueSlotModel(
          id: 'suggest_${gap.toIso8601String()}_${slot.id}',
          time: slot.time,
          label: '${slot.label} (${gap.month}/${gap.day})',
        ));
      }
    }
    return suggestions;
  }

  static List<PostModel> getRecyclablePosts({
    required List<PostModel> allPosts,
    required int minAgeDays,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: minAgeDays));
    return allPosts.where((p) {
      if (p.status != 'published') return false;
      if (p.postedAt == null) return false;
      return p.postedAt!.isBefore(cutoff);
    }).toList();
  }

  static PostModel? suggestBestRecyclablePost({
    required List<PostModel> publishedPosts,
    required DateTime targetDate,
  }) {
    if (publishedPosts.isEmpty) return null;

    final sorted = List<PostModel>.from(publishedPosts)
      ..sort((a, b) {
        final aEngagement = a.likesCount + a.comments;
        final bEngagement = b.likesCount + b.comments;
        return bEngagement.compareTo(aEngagement);
      });

    final best = sorted.first;
    return best.copyWith(
      id: 'recycled_${DateTime.now().millisecondsSinceEpoch}',
      scheduledTime: targetDate,
      status: 'scheduled',
      postedAt: null,
    );
  }
}
