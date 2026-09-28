import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final dynamic time;
  final String priority;
  final bool completed;

  const TaskCard({
    super.key,
    required this.title,
    required this.time,
    required this.priority,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    String formattedTime;

    if (time is TimeOfDay) {
      formattedTime = time.format(context);
    } else {
      formattedTime = time.toString();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,

      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,

          color: completed ? const Color(0xFF1FA8FF) : Colors.grey,
        ),

        title: Text(
          title,

          style: TextStyle(
            fontWeight: FontWeight.w600,

            decoration: completed
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),

        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),

          child: Text('$formattedTime • $priority Priority'),
        ),

        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
