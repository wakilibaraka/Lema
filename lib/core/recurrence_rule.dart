/// The repeat rule alone, free of Flutter so the daemon can import this file.
/// Keeps [base]'s time of day. Occurrences already missed are skipped rather
/// than stacked up. Null when the post does not repeat.
DateTime? nextSlot(
    DateTime base, String recurrence, List<int> weekdays, DateTime now) {
  if (recurrence == 'none') return null;
  final days = recurrence == 'daily'
      ? const [1, 2, 3, 4, 5, 6, 7]
      : weekdays.isEmpty
          ? [base.weekday]
          : weekdays;
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
