import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../schedule/add_schedule_page.dart';
import '../schedule/schedule_card.dart';
import '../services/notification_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<Map<String, dynamic>> schedules = [];

  bool isLoading = true;

  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    loadSchedules();
  }

  // =========================
  // LOAD
  // =========================

  Future<void> loadSchedules() async {
    final data = await DatabaseHelper.instance.getSchedules();

    if (!mounted) return;

    setState(() {
      schedules = data;
      isLoading = false;
    });
  }

  // =========================
  // FILTER
  // =========================

  List<Map<String, dynamic>> get filteredSchedules {
    return schedules.where((schedule) {
      final date = DateTime.tryParse(schedule['date']);

      if (date == null) {
        return false;
      }

      return date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
    }).toList();
  }

  // =========================
  // ADD
  // =========================

  Future<void> addSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const AddSchedulePage();
        },
      ),
    );

    if (result == true) {
      await loadSchedules();
    }
  }

  // =========================
  // EDIT
  // =========================

  Future<void> editSchedule(Map<String, dynamic> schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return AddSchedulePage(schedule: schedule);
        },
      ),
    );

    if (result == true) {
      await loadSchedules();
    }
  }

  // =========================
  // DELETE
  // =========================

  Future<void> deleteSchedule(Map<String, dynamic> schedule) async {
    final scheduleId = schedule['id'];

    await NotificationService.instance.cancelNotification(
      NotificationService.scheduleIdToNotificationId(scheduleId),
    );

    await DatabaseHelper.instance.deleteSchedule(scheduleId);

    await loadSchedules();
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    final filtered = filteredSchedules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),

        actions: [
          IconButton(onPressed: addSchedule, icon: const Icon(Icons.add)),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Select Date',

                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    elevation: 0,

                    child: CalendarDatePicker(
                      initialDate: selectedDate,

                      firstDate: DateTime(2025),

                      lastDate: DateTime(2035),

                      onDateChanged: (date) {
                        setState(() {
                          selectedDate = date;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    'Schedule for '
                    '${selectedDate.day}/'
                    '${selectedDate.month}/'
                    '${selectedDate.year}',

                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (filtered.isEmpty)
                    Card(
                      elevation: 0,

                      child: Padding(
                        padding: const EdgeInsets.all(30),

                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.event_busy,
                                size: 45,
                                color: Colors.grey,
                              ),

                              const SizedBox(height: 10),

                              const Text(
                                'Tidak ada schedule '
                                'pada tanggal ini.',
                                style: TextStyle(color: Colors.grey),
                              ),

                              const SizedBox(height: 15),

                              OutlinedButton.icon(
                                onPressed: addSchedule,

                                icon: const Icon(Icons.add),

                                label: const Text('Add Schedule'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    ...filtered.map((schedule) {
                      return Card(
                        elevation: 0,

                        margin: const EdgeInsets.only(bottom: 12),

                        child: Column(
                          children: [
                            ScheduleCard(
                              time:
                                  '${schedule['start_time']} - ${schedule['end_time']}',

                              title: schedule['title'],

                              location: schedule['location'] ?? '-',
                            ),

                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 10,
                              ),

                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,

                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      editSchedule(schedule);
                                    },

                                    icon: const Icon(Icons.edit, size: 18),

                                    label: const Text('Edit'),
                                  ),

                                  TextButton.icon(
                                    onPressed: () {
                                      deleteSchedule(schedule);
                                    },

                                    icon: const Icon(Icons.delete, size: 18),

                                    label: const Text('Delete'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: addSchedule,

        child: const Icon(Icons.add),
      ),
    );
  }
}
