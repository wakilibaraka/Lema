import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


/// The one schedule picker all three scheduling surfaces use.
///
/// Before this, the omnichannel composer could only choose a day (the time
/// stayed frozen at "three hours from now"), the queue's Create Post modal
/// had no picker at all, and the grid editor could only step 15 minutes at a
/// time — so moving a post to next Tuesday meant 96 taps.
///
/// Returns the chosen local time, or null when dismissed.
Future<DateTime?> showScheduleTimePicker({
  required BuildContext context,
  required DateTime initial,
}) {
  final now = DateTime.now();
  // Nothing can be scheduled into the past; an overdue slot opens at today.
  final minDate = DateTime(now.year, now.month, now.day);
  final start = initial.isBefore(minDate) ? minDate : initial;
  var selected = start;

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancel'),
                ),
                Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: () => Navigator.of(sheetContext).pop(selected),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: start,
                minimumDate: minDate,
                minuteInterval: 5,
                use24hFormat: false,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Shared presentation for a schedule, so every surface formats a slot the
/// same way (the composer printed "10/13 at 9:5" for 09:05).
String formatScheduleSlot(DateTime time) =>
    '${_monthDay(time)} at ${_timeOfDay(time)}';

String _monthDay(DateTime t) =>
    '${_months[t.month - 1]} ${t.day}';

String _timeOfDay(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Colours a schedule line so an already-passed slot reads as late.
Color scheduleColor(DateTime time, bool isDark, {bool overdue = false}) {
  if (overdue) return const Color(0xFFFF9500);
  return isDark ? Colors.white70 : Colors.black87;
}
