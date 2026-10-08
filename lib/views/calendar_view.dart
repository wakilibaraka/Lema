import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/post_model.dart';
import '../providers/posts_provider.dart';
import '../theme/apple_theme.dart';
import '../widgets/apple_glass_card.dart';
import '../widgets/media_player_widget.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<PostModel> _getPostsForDay(DateTime day, List<PostModel> posts) {
    return posts.where((post) => isSameDay(post.scheduledTime, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postsProvider = context.watch<PostsProvider>();
    final allPosts = postsProvider.posts;
    final selectedPosts = _getPostsForDay(_selectedDay ?? _focusedDay, allPosts);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Content Calendar',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Interactive editorial timeline and cross-network campaign orchestrator.',
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

            // Main Calendar + Day Feed Layout
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Calendar Widget
                  Expanded(
                    flex: 6,
                    child: AppleGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TableCalendar<PostModel>(
                            firstDay: DateTime.utc(2025, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            eventLoader: (day) => _getPostsForDay(day, allPosts),
                            startingDayOfWeek: StartingDayOfWeek.monday,
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              todayDecoration: BoxDecoration(
                                color: AppleTheme.systemBlue.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: AppleTheme.systemBlue,
                                shape: BoxShape.circle,
                              ),
                              markerDecoration: const BoxDecoration(
                                color: AppleTheme.systemGreen,
                                shape: BoxShape.circle,
                              ),
                              markersMaxCount: 3,
                              defaultTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
                              weekendTextStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                            ),
                            headerStyle: HeaderStyle(
                              formatButtonVisible: true,
                              titleCentered: true,
                              formatButtonShowsNext: false,
                              titleTextStyle: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              formatButtonDecoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              formatButtonTextStyle: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              leftChevronIcon: Icon(CupertinoIcons.chevron_left, color: isDark ? Colors.white : Colors.black, size: 18),
                              rightChevronIcon: Icon(CupertinoIcons.chevron_right, color: isDark ? Colors.white : Colors.black, size: 18),
                            ),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() => _calendarFormat = format);
                            },
                          ),
                          const Divider(height: 24),
                          // Stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Total Scheduled', '${postsProvider.scheduledPosts.length}', AppleTheme.systemBlue),
                              _buildStatItem('Published', '${postsProvider.publishedPosts.length}', AppleTheme.systemGreen),
                              _buildStatItem('Video Reels', '${allPosts.where((p) => p.isVideo).length}', AppleTheme.systemPurple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Right: Day's Scheduled Posts
                  Expanded(
                    flex: 4,
                    child: AppleGlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.calendar_today, size: 18, color: AppleTheme.systemBlue),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDay != null
                                    ? DateFormat('EEEE, MMM d').format(_selectedDay!)
                                    : 'Selected Day',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppleTheme.systemBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${selectedPosts.length} posts',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppleTheme.systemBlue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: selectedPosts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.calendar_badge_plus, size: 38, color: isDark ? Colors.white24 : Colors.black26),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No posts scheduled for this date.',
                                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: selectedPosts.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final post = selectedPosts[index];
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: SizedBox(
                                                width: 50,
                                                height: 50,
                                                child: UniversalMediaPlayer(
                                                  mediaUrl: post.mediaUrl,
                                                  isVideo: post.isVideo,
                                                  autoPlay: false,
                                                  showControls: false,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        DateFormat('h:mm a').format(post.scheduledTime),
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: post.platformInfo.color.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          post.platformInfo.name,
                                                          style: TextStyle(color: post.platformInfo.color, fontSize: 9.5, fontWeight: FontWeight.w700),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    post.caption,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark ? Colors.white70 : Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
