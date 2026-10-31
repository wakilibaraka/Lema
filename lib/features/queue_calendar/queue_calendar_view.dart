import 'package:flutter/material.dart';

import '../../views/calendar_view.dart';
import '../../views/queue_view.dart';

/// Queue and calendar share one destination: the list of what is next, and
/// the same posts laid out in time.
class QueueCalendarView extends StatelessWidget {
  const QueueCalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            tabs: [Tab(text: 'Queue'), Tab(text: 'Calendar')],
          ),
          Expanded(
            child: TabBarView(
              physics: NeverScrollableScrollPhysics(),
              children: [QueueView(), CalendarView()],
            ),
          ),
        ],
      ),
    );
  }
}
