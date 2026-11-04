import 'models/post_model.dart';

/// The next time a repeating post should go out, keeping its time of day.
/// Occurrences missed while the app was closed are skipped rather than
/// stacked up. Null when the post does not repeat.
DateTime? nextOccurrence(PostModel post, DateTime now) {
  if (post.recurrence == recurrenceNone) return null;
  final base = post.scheduledTime;
  final days = post.recurrence == recurrenceDaily
      ? const [1, 2, 3, 4, 5, 6, 7]
      : post.recurrenceDays.isEmpty
          ? [base.weekday]
          : post.recurrenceDays;
  final from = base.isAfter(now) ? base : now;
  // Calendar arithmetic, so a daylight-saving change can't shift the time.
  for (var i = 0; i <= 8; i++) {
    final candidate =
        DateTime(from.year, from.month, from.day + i, base.hour, base.minute);
    if (candidate.isAfter(base) &&
        candidate.isAfter(now) &&
        days.contains(candidate.weekday)) {
      return candidate;
    }
  }
  return null;
}
