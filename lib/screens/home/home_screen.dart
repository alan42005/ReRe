import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/screens/add_task/add_task_screen.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/notification_service.dart';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Box<Task> tasksBox = Hive.box<Task>('tasks');
  final Box settingsBox = Hive.box('settings');
  final TextEditingController _nameController = TextEditingController();

  void _showEditNameDialog() {
    _nameController.text = settingsBox.get('userName', defaultValue: 'User');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Your Name'),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  settingsBox.put('userName', _nameController.text);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: _showEditNameDialog,
            child: const CircleAvatar(
              backgroundImage: NetworkImage('https://placehold.co/100x100/png'),
              child: Icon(Icons.edit, color: Colors.white70, size: 16),
            ),
          ),
        ),
        title: ValueListenableBuilder(
          valueListenable: settingsBox.listenable(),
          builder: (context, box, _) {
            final userName = box.get('userName', defaultValue: 'User');
            return Text(
              'Hallo, $userName!',
              style: const TextStyle(
                  color: AppColors.textDark, fontWeight: FontWeight.bold),
            );
          },
        ),
        actions: [
          // New Test Notification Button
          IconButton(
            icon: const Icon(Icons.science_outlined, color: AppColors.textDark),
            tooltip: 'Test Notification',
            onPressed: () {
              NotificationService().showTestNotification();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none,
                color: AppColors.textDark, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: tasksBox.listenable(),
        builder: (context, Box<Task> box, _) {
          final tasks = box.values.toList().cast<Task>()
            ..sort((a, b) {
              if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
              return a.startTime.compareTo(b.startTime);
            });

          final completedTasks = tasks.where((task) => task.isCompleted).length;
          final totalTasks = tasks.length;
          final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textDark),
                      SizedBox(width: 8),
                      Text('Today',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_drop_down, color: AppColors.textDark),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ProgressDial(
                    progress: progress,
                    completed: completedTasks,
                    target: totalTasks),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('My Tasks',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AddTaskScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                tasks.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                              "You have no tasks yet. Tap '+' to add one!",
                              style: TextStyle(
                                  color: AppColors.textLight, fontSize: 16),
                              textAlign: TextAlign.center),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final taskKey = task.key as int;
                          return TaskItem(task: task, taskKey: taskKey);
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProgressDial extends StatelessWidget {
  final double progress;
  final int completed;
  final int target;

  const ProgressDial(
      {super.key,
      required this.progress,
      required this.completed,
      required this.target});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: AspectRatio(
        aspectRatio: 1.2,
        child: CustomPaint(
          painter: DialPainter(progress: progress),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${(progress * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [
                    const Text('Completed',
                        style: TextStyle(color: AppColors.textLight)),
                    Text('$completed',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18))
                  ]),
                  Column(children: [
                    const Text('Target',
                        style: TextStyle(color: AppColors.textLight)),
                    Text('$target',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18))
                  ]),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Level 1',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(width: 10),
                  Text('Good Job!')
                ]),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class DialPainter extends CustomPainter {
  final double progress;
  DialPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.9;
    const strokeWidth = 12.0;
    final backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final progressPaint = Paint()
      ..shader =
          LinearGradient(colors: [AppColors.secondary, AppColors.primary])
              .createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.75, math.pi * 1.5, false, backgroundPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.75, math.pi * 1.5 * progress, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TaskItem extends StatelessWidget {
  final Task task;
  final int taskKey;

  const TaskItem({super.key, required this.task, required this.taskKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            onChanged: (bool? value) {
              task.isCompleted = value ?? false;
              task.save();
              if (task.isCompleted) {
                NotificationService().cancelNotification(taskKey);
                NotificationService().cancelNotification(taskKey + 1000000);
              }
            },
            activeColor: AppColors.primary,
            side: BorderSide(color: Colors.grey.shade400, width: 2),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: task.isCompleted
                          ? AppColors.textLight
                          : AppColors.textDark,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none),
                ),
                const SizedBox(height: 4),
                Text(
                  "${DateFormat.yMMMd().format(task.startTime)} (${DateFormat.jm().format(task.startTime)} - ${DateFormat.jm().format(task.endTime)})",
                  style:
                      const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
          ),
          if (task.reminderMinutesBefore != null &&
              task.reminderMinutesBefore! > 0)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Icon(Icons.notifications_active,
                  color: AppColors.accent, size: 18),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              NotificationService().cancelNotification(taskKey);
              NotificationService().cancelNotification(taskKey + 1000000);
              task.delete();
            },
          ),
        ],
      ),
    );
  }
}
