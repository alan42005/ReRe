import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/screens/focus/focus_screen.dart';
import 'package:flutter/services.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/notification_service.dart';
import 'package:reminder_app/utils/widget_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:collection';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final Box<Task> tasksBox;
  late final ValueNotifier<List<Task>> _selectedTasks;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  LinkedHashMap<DateTime, List<Task>> _events = LinkedHashMap();

  @override
  void initState() {
    super.initState();
    tasksBox = Hive.box<Task>('tasks');
    _selectedDay = _focusedDay;
    _groupTasksByDay();
    _selectedTasks = ValueNotifier(_getTasksForDay(_selectedDay!));
  }

  void _groupTasksByDay() {
    _events = LinkedHashMap<DateTime, List<Task>>(
      equals: isSameDay,
      hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
    );
    for (var task in tasksBox.values) {
      final day = DateTime.utc(
          task.startTime.year, task.startTime.month, task.startTime.day);
      if (_events[day] == null) {
        _events[day] = [];
      }
      _events[day]!.add(task);
    }
  }

  List<Task> _getTasksForDay(DateTime day) {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    return _events[utcDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _selectedTasks.value = _getTasksForDay(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Calendar View',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: ValueListenableBuilder<Box<Task>>(
        valueListenable: tasksBox.listenable(),
        builder: (context, box, _) {
          _groupTasksByDay();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedDay != null) {
              _selectedTasks.value = _getTasksForDay(_selectedDay!);
            }
          });
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: TableCalendar<Task>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    eventLoader: _getTasksForDay,
                    calendarFormat: CalendarFormat.month,
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                      markerDecoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ValueListenableBuilder<List<Task>>(
                  valueListenable: _selectedTasks,
                  builder: (context, tasks, _) {
                    if (tasks.isEmpty) {
                      return const Center(
                        child: Text(
                          "No schedule blocks for this day.",
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 15),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _buildCalendarTaskItem(task);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarTaskItem(Task task) {
    final taskKey = task.key as int?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: AppColors.primary,
            onChanged: (val) {
              HapticFeedback.mediumImpact();
              task.isCompleted = val ?? false;
              task.save();
              WidgetService.updatePrioritiesWidget();
              if (task.isCompleted && taskKey != null) {
                NotificationService().cancelNotification(taskKey);
                NotificationService().cancelNotification(taskKey + 1000000);
              }
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                const SizedBox(height: 4),
                Text(
                  "${DateFormat.jm().format(task.startTime)} - ${DateFormat.jm().format(task.endTime)}",
                  style:
                      const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.timer_outlined,
                color: AppColors.accent, size: 20),
            tooltip: 'Focus',
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
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 20),
            onPressed: () {
              if (taskKey != null) {
                NotificationService().cancelNotification(taskKey);
                NotificationService().cancelNotification(taskKey + 1000000);
              }
              task.delete();
              WidgetService.updatePrioritiesWidget();
            },
          ),
        ],
      ),
    );
  }
}
