import 'package:flutter/material.dart';

class ScheduleCard extends StatelessWidget {
  final String time;
  final String title;
  final String location;

  const ScheduleCard({
    super.key,
    required this.time,
    required this.title,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF6FF),
          child: const Icon(Icons.event, color: Color(0xFF1FA8FF)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('$time • $location'),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
