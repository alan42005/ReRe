import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/models/habit.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/screens/add_task/add_task_screen.dart';
import 'package:reminder_app/screens/focus/focus_screen.dart';
import 'package:reminder_app/screens/habits/add_habit_dialog.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/notification_service.dart';
import 'dart:math' as math;

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final Box<Task> tasksBox = Hive.box<Task>('tasks');
  final Box<Habit> habitsBox = Hive.box<Habit>('habits');
  final Box settingsBox = Hive.box('settings');

  DateTime _selectedDate = DateTime.now();

  void _changeDate(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
  }

  void _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _changeDate(picked);
    }
  }

  void _showEditNameDialog() {
    final controller = TextEditingController(
      text: settingsBox.get('userName', defaultValue: 'Champion'),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Your Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter your name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                settingsBox.put('userName', controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textDark,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Rollover all incomplete tasks from before selectedDate to selectedDate
  void _rolloverIncompleteTasks(List<Task> overdueTasks) async {
    for (var task in overdueTasks) {
      final oldDuration = task.endTime.difference(task.startTime);
      final newStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        task.startTime.hour,
        task.startTime.minute,
      );
      task.startTime = newStart;
      task.endTime = newStart.add(oldDuration);
      await task.save();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Rolled over ${overdueTasks.length} tasks to ${DateFormat.MMMd().format(_selectedDate)}!'),
          backgroundColor: Colors.black87,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: _showEditNameDialog,
            child: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, color: AppColors.textDark, size: 20),
            ),
          ),
        ),
        title: ValueListenableBuilder(
          valueListenable: settingsBox.listenable(),
          builder: (context, box, _) {
            final userName = box.get('userName', defaultValue: 'Champion');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $userName! 👋',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  DateFormat('EEEE, MMM d').format(_selectedDate),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.textDark),
            tooltip: 'Pick Date',
            onPressed: _pickCustomDate,
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined, color: AppColors.textDark),
            tooltip: 'Test Notification',
            onPressed: () => NotificationService().showTestNotification(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ValueListenableBuilder<Box<Task>>(
        valueListenable: tasksBox.listenable(),
        builder: (context, Box<Task> box, _) {
          final allTasks = box.values.toList().cast<Task>();

          // Filter tasks for the selected date
          final dayTasks = allTasks.where((t) {
            return t.startTime.year == _selectedDate.year &&
                t.startTime.month == _selectedDate.month &&
                t.startTime.day == _selectedDate.day;
          }).toList()
            ..sort((a, b) {
              // Sort by completion, then priority, then startTime
              if (a.isCompleted != b.isCompleted) {
                return a.isCompleted ? 1 : -1;
              }
              if (a.priority != b.priority) {
                return a.priority.compareTo(b.priority);
              }
              return a.startTime.compareTo(b.startTime);
            });

          // Top 3 Priorities for this day
          final topPriorities =
              dayTasks.where((t) => t.isTopPriority).take(3).toList();

          // Check for overdue unfinished tasks from past days
          final overdueTasks = isToday
              ? allTasks.where((t) {
                  final taskDay = DateTime(
                      t.startTime.year, t.startTime.month, t.startTime.day);
                  final todayStart = DateTime(
                      DateTime.now().year, DateTime.now().month, DateTime.now().day);
                  return taskDay.isBefore(todayStart) && !t.isCompleted;
                }).toList()
              : <Task>[];

          final completedTasks = dayTasks.where((t) => t.isCompleted).length;
          final totalTasks = dayTasks.length;
          final progress =
              totalTasks > 0 ? completedTasks / totalTasks : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Bar (Yesterday, Today, Tomorrow)
                _buildDateSelectorRow(),
                const SizedBox(height: 16),

                // Overdue Rollover Banner
                if (overdueTasks.isNotEmpty) ...[
                  _buildRolloverBanner(overdueTasks),
                  const SizedBox(height: 16),
                ],

                // Compact Progress Card
                _buildProgressCard(progress, completedTasks, totalTasks),
                const SizedBox(height: 20),

                // Daily Habits Quick-Check Bar
                _buildDailyHabitsBar(),
                const SizedBox(height: 24),

                // Top 3 Priorities Section
                if (topPriorities.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.priorityHigh, size: 22),
                      const SizedBox(width: 6),
                      const Text(
                        'Top Priorities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${topPriorities.where((t) => t.isCompleted).length}/${topPriorities.length}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...topPriorities.map((task) => _buildTaskCard(task, isPriorityCard: true)),
                  const SizedBox(height: 20),
                ],

                // Daily Schedule / Time-Blocking Agenda
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Schedule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddTaskScreen(initialDate: _selectedDate),
                        ),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Block'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (dayTasks.isEmpty)
                  _buildEmptySchedule()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: dayTasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildTaskCard(dayTasks[index]);
                    },
                  ),

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateSelectorRow() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _dateChip('Yesterday', yesterday),
          const SizedBox(width: 8),
          _dateChip('Today', now),
          const SizedBox(width: 8),
          _dateChip('Tomorrow', tomorrow),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
              DateFormat('MMM d').format(_selectedDate),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.cardBorder),
            onPressed: _pickCustomDate,
          ),
        ],
      ),
    );
  }

  Widget _dateChip(String label, DateTime date) {
    final isSelected = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(date);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppColors.textDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      side: const BorderSide(color: AppColors.cardBorder),
      onSelected: (val) {
        if (val) _changeDate(date);
      },
    );
  }

  Widget _buildRolloverBanner(List<Task> overdueTasks) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEEBA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_toggle_off_rounded,
              color: Color(0xFF856404), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${overdueTasks.length} Unfinished Tasks',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF856404),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Would you like to roll them over to today\'s schedule?',
                  style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _rolloverIncompleteTasks(overdueTasks),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF856404),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Rollover'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double progress, int completed, int target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: CustomPaint(
              painter: PlannerDialPainter(progress: progress),
              child: Center(
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed == target && target > 0
                      ? 'All Tasks Finished! 🏆'
                      : '$completed of $target Tasks Done',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  completed == target && target > 0
                      ? 'You crushed today\'s goals. Take time to relax!'
                      : 'Stay focused and knock out your key blocks.',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHabitsBar() {
    return ValueListenableBuilder<Box<Habit>>(
      valueListenable: habitsBox.listenable(),
      builder: (context, box, _) {
        final habits = box.values.toList();
        if (habits.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Habits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => const AddHabitDialog(),
                  ),
                  child: const Text(
                    '+ Add',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: habits.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  final isDone = habit.isCompletedOn(_selectedDate);
                  final color = Color(habit.colorValue);

                  return GestureDetector(
                    onTap: () => setState(() => habit.toggleCompletion(_selectedDate)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDone ? color : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDone ? color : AppColors.cardBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isDone ? Icons.check_circle : Icons.circle_outlined,
                            size: 18,
                            color: isDone ? Colors.white : color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            habit.title,
                            style: TextStyle(
                              color: isDone ? Colors.white : AppColors.textDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(Task task, {bool isPriorityCard = false}) {
    final taskKey = task.key as int?;
    final timeSpan =
        "${DateFormat.jm().format(task.startTime)} - ${DateFormat.jm().format(task.endTime)}";

    Color priorityColor = AppColors.priorityMedium;
    if (task.priority == 1) priorityColor = AppColors.priorityHigh;
    if (task.priority == 3) priorityColor = AppColors.priorityLow;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPriorityCard
              ? priorityColor.withValues(alpha: 0.6)
              : AppColors.cardBorder,
          width: isPriorityCard ? 1.5 : 1,
        ),
        boxShadow: [
          if (isPriorityCard)
            BoxShadow(
              color: priorityColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: (bool? val) {
                  task.isCompleted = val ?? false;
                  task.save();
                  if (task.isCompleted && taskKey != null) {
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
                    Row(
                      children: [
                        if (task.priority == 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.priorityHigh.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TOP PRIORITY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.priorityHigh,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: task.isCompleted
                                  ? AppColors.textLight
                                  : AppColors.textDark,
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          timeSpan,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12),
                        ),
                        if (task.focusMinutesSpent > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⏱️ ${task.focusMinutesSpent}m focused',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Focus Button (Launch Pomodoro directly for this task)
              IconButton(
                icon: const Icon(Icons.timer_outlined,
                    color: AppColors.accent, size: 22),
                tooltip: 'Focus on this task',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) =>
                          FocusScreen(initialTaskTitle: task.title),
                    ),
                  );
                },
              ),
              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: () {
                  if (taskKey != null) {
                    NotificationService().cancelNotification(taskKey);
                    NotificationService().cancelNotification(taskKey + 1000000);
                  }
                  task.delete();
                },
              ),
            ],
          ),
          if (task.notes != null && task.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 12),
              child: Text(
                task.notes!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySchedule() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 44, color: AppColors.accent),
          const SizedBox(height: 12),
          const Text(
            'No Time Blocks Planned',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Plan out your key tasks and time blocks for this day to maintain flow and avoid distractions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddTaskScreen(initialDate: _selectedDate),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Time Block'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class PlannerDialPainter extends CustomPainter {
  final double progress;
  PlannerDialPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.85;
    const strokeWidth = 7.0;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.secondary, AppColors.primary],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
