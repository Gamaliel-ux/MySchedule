import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../services/notification_service.dart';

class AddSchedulePage extends StatefulWidget {
  final Map<String, dynamic>? schedule;

  const AddSchedulePage({super.key, this.schedule});

  bool get isEditing => schedule != null;

  @override
  State<AddSchedulePage> createState() => _AddSchedulePageState();
}

class _AddSchedulePageState extends State<AddSchedulePage> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();

  final descriptionController = TextEditingController();

  final locationController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  TimeOfDay? startTime;

  TimeOfDay? endTime;

  int reminderMinutes = 60;

  String alarmSound = 'default_alarm';

  static const List<int> _validReminderMinutes = [
    5,
    15,
    30,
    60,
    120,
    180,
    360,
    720,
    1440,
  ];

  Future<void> _loadAlarmSoundPreference() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      alarmSound = prefs.getString('selected_alarm_sound') ?? 'default_alarm';
    });
  }

  @override
  void initState() {
    super.initState();

    if (widget.schedule != null) {
      final schedule = widget.schedule!;

      titleController.text = schedule['title'] ?? '';

      descriptionController.text = schedule['description'] ?? '';

      locationController.text = schedule['location'] ?? '';

      if (schedule['date'] != null) {
        final parsedDate = DateTime.tryParse(schedule['date']);

        if (parsedDate != null) {
          selectedDate = parsedDate;
        }
      }

      startTime = _parseTime(schedule['start_time']);

      endTime = _parseTime(schedule['end_time']);

      final storedReminder = (schedule['reminder_minutes'] ?? 60) as int;
      reminderMinutes = _validReminderMinutes.contains(storedReminder)
          ? storedReminder
          : 60;
      alarmSound = schedule['alarm_sound'] ?? 'default_alarm';
    } else {
      reminderMinutes = 60;
      _loadAlarmSoundPreference();
    }
  }

  // =========================
  // PARSE TIME
  // =========================

  TimeOfDay? _parseTime(String? value) {
    if (value == null) {
      return null;
    }

    try {
      final parts = value.split(' ');

      final time = parts[0].split(':');

      int hour = int.parse(time[0]);

      int minute = int.parse(time[1]);

      if (parts.length > 1) {
        final period = parts[1].toUpperCase();

        if (period == 'PM' && hour != 12) {
          hour += 12;
        }

        if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();

    super.dispose();
  }

  // =========================
  // DATE
  // =========================

  Future<void> selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  // =========================
  // START TIME
  // =========================

  Future<void> selectStartTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        startTime = pickedTime;
      });
    }
  }

  // =========================
  // END TIME
  // =========================

  Future<void> selectEndTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        endTime = pickedTime;
      });
    }
  }

  // =========================
  // SAVE
  // =========================

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  Future<void> saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih jam mulai dan selesai.')),
      );

      return;
    }

    final startMinutes = startTime!.hour * 60 + startTime!.minute;
    final endMinutes = endTime!.hour * 60 + endTime!.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jam selesai harus lebih akhir dari jam mulai.'),
        ),
      );

      return;
    }

    final formattedStartTime = _formatTimeOfDay(startTime!);
    final formattedEndTime = _formatTimeOfDay(endTime!);

    final schedule = {
      'title': titleController.text.trim(),

      'description': descriptionController.text.trim(),

      'date': selectedDate.toIso8601String(),

      'start_time': formattedStartTime,

      'end_time': formattedEndTime,

      'location': locationController.text.trim(),
      'reminder_minutes': reminderMinutes,
      'alarm_sound': alarmSound,
    };

    int scheduleId;

    if (widget.isEditing) {
      scheduleId = widget.schedule!['id'];

      await NotificationService.instance.cancelNotification(
        NotificationService.scheduleIdToNotificationId(scheduleId),
      );

      await DatabaseHelper.instance.updateSchedule(scheduleId, schedule);
    } else {
      scheduleId = await DatabaseHelper.instance.insertSchedule(schedule);
    }

    final targetNotifId = NotificationService.scheduleIdToNotificationId(
      scheduleId,
    );

    final startDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startTime!.hour,
      startTime!.minute,
    );

    final reminderDate = startDate.subtract(
      Duration(minutes: reminderMinutes),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_alarm_sound', alarmSound);

    await NotificationService.instance.scheduleNotification(
      id: targetNotifId,
      title: titleController.text.trim(),
      body:
          'Reminder: ${titleController.text.trim()} dimulai $formattedStartTime',
      scheduledDate: reminderDate,
      alarmSound: alarmSound,
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Schedule' : 'Add Schedule'),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Schedule Title',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: titleController,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableIMEPersonalizedLearning: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Judul schedule',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Judul schedule wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Description',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: const InputDecoration(
                    hintText: 'Deskripsi schedule...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Date',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                InkWell(
                  onTap: selectDate,

                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),

                    child: Text(
                      '${selectedDate.day}/'
                      '${selectedDate.month}/'
                      '${selectedDate.year}',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Start Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                InkWell(
                  onTap: selectStartTime,

                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),

                    child: Text(
                      startTime == null
                          ? 'Select start time'
                          : startTime!.format(context),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'End Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                InkWell(
                  onTap: selectEndTime,

                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),

                    child: Text(
                      endTime == null
                          ? 'Select end time'
                          : endTime!.format(context),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Reminder',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<int>(
                  initialValue: reminderMinutes,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alarm_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                    DropdownMenuItem(
                      value: 15,
                      child: Text('15 minutes before'),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text('30 minutes before'),
                    ),
                    DropdownMenuItem(value: 60, child: Text('1 hour before')),
                    DropdownMenuItem(value: 120, child: Text('2 hours before')),
                    DropdownMenuItem(value: 180, child: Text('3 hours before')),
                    DropdownMenuItem(value: 360, child: Text('6 hours before')),
                    DropdownMenuItem(
                      value: 720,
                      child: Text('12 hours before'),
                    ),
                    DropdownMenuItem(value: 1440, child: Text('1 day before')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        reminderMinutes = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Alarm Sound',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                DropdownButtonFormField<String>(
                  initialValue: alarmSound,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.music_note_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'default_alarm',
                      child: Text('Default alarm'),
                    ),
                    DropdownMenuItem(
                      value: 'soft_chime',
                      child: Text('Soft chime'),
                    ),
                    DropdownMenuItem(
                      value: 'urgent_buzz',
                      child: Text('Urgent buzz'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        alarmSound = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 20),

                const Text(
                  'Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: locationController,
                  textInputAction: TextInputAction.next,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: const InputDecoration(
                    hintText: 'Lokasi schedule',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: saveSchedule,
                    icon: Icon(
                      widget.isEditing ? Icons.save : Icons.event_available,
                    ),
                    label: Text(
                      widget.isEditing ? 'Update Schedule' : 'Save Schedule',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
