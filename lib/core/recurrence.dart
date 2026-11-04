import 'models/post_model.dart';
import 'recurrence_rule.dart';

/// The next time a repeating post should go out. Null when it does not repeat.
DateTime? nextOccurrence(PostModel post, DateTime now) => nextSlot(
    post.scheduledTime, post.recurrence, post.recurrenceDays, now);
