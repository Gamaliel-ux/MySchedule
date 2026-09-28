import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../services/notification_service.dart';

class AddTaskPage extends StatefulWidget {
  final Map<String, dynamic>? task;

  const AddTaskPage({super.key, this.task});

  bool get isEditing => task != null;

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();

  final descriptionController = TextEditingController();

  DateTime selectedDate = DateTime.now();

  TimeOfDay? selectedTime;

  String selectedPriority = 'Medium';

  String selectedCategory = 'Kuliah';

  int reminderMinutes = 10;

  String alarmSound = 'default_alarm';

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

    if (widget.task != null) {
      final task = widget.task!;

      titleController.text = task['title'] ?? '';

      descriptionController.text = task['description'] ?? '';

      if (task['due_date'] != null) {
        final date = DateTime.tryParse(task['due_date'].toString());

        if (date != null) {
          selectedDate = date;
        }
      }

      selectedPriority = task['priority'] ?? 'Medium';
      selectedCategory = task['category'] ?? 'Kuliah';
      alarmSound = task['alarm_sound'] ?? 'default_alarm';
      reminderMinutes = (task['reminder_minutes'] ?? 10) as int;

      if (task['due_time'] != null) {
        selectedTime = _parseTime(task['due_time'].toString());
      }
    } else {
      _loadAlarmSoundPreference();
    }
  }

  // =========================================================
  // PARSE TIME
  // =========================================================

  TimeOfDay? _parseTime(String value) {
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

    super.dispose();
  }

  // =========================================================
  // DATE PICKER
  // =========================================================

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,

      initialDate: selectedDate,

      firstDate: DateTime(2025),

      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // =========================================================
  // TIME PICKER
  // =========================================================

  Future<void> selectTime() async {
    final picked = await showTimePicker(
      context: context,

      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  // =========================================================
  // SAVE TASK
  // =========================================================

  Future<void> saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih waktu task.')),
      );

      return;
    }

    final task = {
      'title': titleController.text.trim(),

      'description': descriptionController.text.trim(),

      'due_date': selectedDate.toIso8601String(),

      'due_time': selectedTime!.format(context),

      'priority': selectedPriority,
      'category': selectedCategory,
      'reminder_minutes': reminderMinutes,
      'alarm_sound': alarmSound,
    };

    int taskId;

    if (widget.isEditing) {
      taskId = widget.task!['id'];

      await DatabaseHelper.instance.updateTask(taskId, task);

      await NotificationService.instance.cancelNotification(
        NotificationService.taskIdToNotificationId(taskId),
      );
    } else {
      taskId = await DatabaseHelper.instance.insertTask({
        ...task,
        'completed': 0,
      });
    }

    final targetNotifId = NotificationService.taskIdToNotificationId(taskId);

    final taskDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    final reminderTime = taskDateTime.subtract(
      Duration(minutes: reminderMinutes),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_alarm_sound', alarmSound);

    await NotificationService.instance.scheduleNotification(
      id: targetNotifId,

      title: 'Task Reminder ($selectedCategory)',

      body: titleController.text.trim(),

      scheduledDate: reminderTime,
      alarmSound: alarmSound,
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit Task' : 'Add Task')),
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
                  'Task Title',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: titleController,
                  textInputAction: TextInputAction.next,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Belajar Flutter',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.task_alt),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Judul task wajib diisi';
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
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  enableSuggestions: false,
                  autocorrect: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: const InputDecoration(
                    hintText: 'Tambahkan detail task...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Due Date',
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
                  'Due Time',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: selectTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    child: Text(
                      selectedTime == null
                          ? 'Select time'
                          : selectedTime!.format(context),
                    ),
                  ),
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
                  'Category',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Kuliah', child: Text('Kuliah')),
                    DropdownMenuItem(value: 'Pribadi', child: Text('Pribadi')),
                    DropdownMenuItem(value: 'Kerja', child: Text('Kerja')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Priority',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedPriority = value;
                      });
                    }
                  },
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
                    prefixIcon: Icon(Icons.notifications_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('At time of task')),
                    DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                    DropdownMenuItem(
                      value: 10,
                      child: Text('10 minutes before'),
                    ),
                    DropdownMenuItem(
                      value: 30,
                      child: Text('30 minutes before'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        reminderMinutes = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: saveTask,
                    icon: Icon(widget.isEditing ? Icons.save : Icons.add_task),
                    label: Text(
                      widget.isEditing ? 'Update Task' : 'Save Task',
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
