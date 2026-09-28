import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../schedule/schedule_card.dart';
import '../services/auth_service.dart';
import '../tasks/task_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> schedules = [];
  List<Map<String, dynamic>> tasks = [];
  String _userName = 'Planner';

  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    loadCurrentUser();
    loadDashboardData();
  }

  Future<void> loadCurrentUser() async {
    final user = await AuthService.currentUser();

    if (!mounted) return;

    setState(() {
      _userName = user?.name.isNotEmpty == true ? user!.name : 'Planner';
    });
  }

  // ==========================================================
  // LOAD DATA
  // ==========================================================

  Future<void> loadDashboardData() async {
    final scheduleData = await DatabaseHelper.instance.getSchedules();

    final taskData = await DatabaseHelper.instance.getTasks();

    if (!mounted) return;

    setState(() {
      schedules = scheduleData;
      tasks = taskData;
      isLoading = false;
    });
  }

  // ==========================================================
  // GREETING
  // ==========================================================

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning 👋';
    }

    if (hour >= 12 && hour < 18) {
      return 'Good Afternoon 👋';
    }

    return 'Good Evening 👋';
  }

  // ==========================================================
  // CHECK TODAY
  // ==========================================================

  bool isToday(String? dateString) {
    if (dateString == null) {
      return false;
    }

    final date = DateTime.tryParse(dateString);

    if (date == null) {
      return false;
    }

    final now = DateTime.now();

    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // ==========================================================
  // FORMAT DATE
  // ==========================================================

  String getTodayText() {
    final now = DateTime.now();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final todaySchedules = schedules
        .where((schedule) => isToday(schedule['date']))
        .toList();

    final todayTasks = tasks
        .where((task) => isToday(task['due_date']))
        .toList();

    final completedTasks = todayTasks
        .where((task) => task['completed'] == 1)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('MySchedule')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1FA8FF), Color(0xFF7CC9FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.white.withAlpha(60),
                            child: Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : 'P',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getGreeting(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hi, $_userName',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  getTodayText(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.calendar_month_rounded,
                            title: 'Schedule',
                            value: todaySchedules.length.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.task_alt_rounded,
                            title: 'Tasks',
                            value: todayTasks.length.toString(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.check_circle_rounded,
                            title: 'Done',
                            value: completedTasks.toString(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 26),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2430),
                          ),
                        ),
                        Text(
                          '${todaySchedules.length} item',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (todaySchedules.isEmpty)
                      _EmptyCard(
                        icon: Icons.calendar_today_rounded,
                        message: 'No schedule for today.',
                      )
                    else
                      ...todaySchedules.map((schedule) {
                        return ScheduleCard(
                          time:
                              '${schedule['start_time']} - ${schedule['end_time']}',
                          title: schedule['title'],
                          location: schedule['location'] ?? '-',
                        );
                      }),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Tasks",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2430),
                          ),
                        ),
                        Text(
                          '$completedTasks/${todayTasks.length} done',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (todayTasks.isEmpty)
                      _EmptyCard(
                        icon: Icons.task_alt_rounded,
                        message: 'No tasks for today.',
                      )
                    else
                      ...todayTasks.map((task) {
                        return TaskCard(
                          title: task['title'],
                          time: task['due_time'],
                          priority: task['priority'],
                          completed: task['completed'] == 1,
                        );
                      }),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}

// ==========================================================
// SUMMARY CARD
// ==========================================================

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// EMPTY CARD
// ==========================================================

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
