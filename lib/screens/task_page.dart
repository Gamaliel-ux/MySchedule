import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../tasks/add_task_page.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  List<Map<String, dynamic>> tasks = [];
  bool isLoading = true;
  String selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  Future<void> loadTasks() async {
    final data = await DatabaseHelper.instance.getTasks();
    if (!mounted) return;

    setState(() {
      tasks = data;
      isLoading = false;
    });
  }

  List<Map<String, dynamic>> get filteredTasks {
    if (selectedCategory == 'Semua') {
      return tasks;
    }
    return tasks.where((task) {
      final cat = task['category'] ?? 'Kuliah';
      return cat == selectedCategory;
    }).toList();
  }

  Future<void> _openAddTask({Map<String, dynamic>? task}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskPage(task: task),
      ),
    );

    if (result == true) {
      await loadTasks();
    }
  }

  Future<void> _toggleTaskCompleted(Map<String, dynamic> task) async {
    final id = task['id'] as int;
    final isCompleted = (task['completed'] ?? 0) == 1;

    await DatabaseHelper.instance.updateTaskCompleted(id, !isCompleted);
    await loadTasks();
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Task'),
        content: Text('Apakah Anda yakin ingin menghapus "${task['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final taskId = task['id'] as int;
      await NotificationService.instance.cancelNotification(
        NotificationService.taskIdToNotificationId(taskId),
      );
      await DatabaseHelper.instance.deleteTask(taskId);
      await loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = filteredTasks;
    final completedTasks = filtered.where((task) => task['completed'] == 1).length;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.task_alt_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tasks',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '${filtered.length} task • $completedTasks completed',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),

              // Add Task Quick Card
              InkWell(
                onTap: () => _openAddTask(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6EBF2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.note_alt_outlined,
                        color: Color(0xFF1FA8FF),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Add a task...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1FA8FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE6EBF2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF1FA8FF),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Semua',
                        child: Row(
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: Color(0xFF1FA8FF),
                            ),
                            SizedBox(width: 8),
                            Text('Semua Kategori'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Kuliah',
                        child: Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              size: 18,
                              color: Color(0xFF1FA8FF),
                            ),
                            SizedBox(width: 8),
                            Text('Kuliah'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Pribadi',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 18,
                              color: Color(0xFF1FA8FF),
                            ),
                            SizedBox(width: 8),
                            Text('Pribadi'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Kerja',
                        child: Row(
                          children: [
                            Icon(
                              Icons.work_rounded,
                              size: 18,
                              color: Color(0xFF1FA8FF),
                            ),
                            SizedBox(width: 8),
                            Text('Kerja'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedCategory = value);
                      }
                    },
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Task List
              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 72,
                          color: Color(0xFF1FA8FF),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'No tasks yet',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Your schedule is clear for now.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.only(bottom: 20),
                    itemBuilder: (context, index) {
                      final task = filtered[index];
                      final completed = (task['completed'] ?? 0) == 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE6EBF2)),
                        ),
                        child: InkWell(
                          onTap: () => _openAddTask(task: task),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: completed,
                                  onChanged: (_) => _toggleTaskCompleted(task),
                                  activeColor: const Color(0xFF1FA8FF),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task['title'] ?? 'Task',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: completed
                                              ? const Color(0xFF98A2B3)
                                              : colorScheme.onSurface,
                                          decoration: completed
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      if (task['due_time'] != null ||
                                          task['priority'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            '${task['due_time'] ?? ''} • ${task['priority'] ?? ''} • ${task['category'] ?? 'Kuliah'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF98A2B3),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () => _deleteTask(task),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
