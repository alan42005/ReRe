import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/screens/home/home_screen.dart'; // Re-using the TaskItem widget
import 'package:reminder_app/utils/app_colors.dart';
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

  // Using a LinkedHashMap is recommended for TableCalendar's events.
  LinkedHashMap<DateTime, List<Task>> _events = LinkedHashMap();

  @override
  void initState() {
    super.initState();
    tasksBox = Hive.box<Task>('tasks');
    _selectedDay = _focusedDay;
    _groupTasksByDay();
    _selectedTasks = ValueNotifier(_getTasksForDay(_selectedDay!));
  }

  // Groups all tasks from the Hive box by the day they start.
  void _groupTasksByDay() {
    _events = LinkedHashMap<DateTime, List<Task>>(
      equals: isSameDay,
      hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
    );
    for (var task in tasksBox.values) {
      // Normalize the date to UTC to avoid timezone issues.
      final day = DateTime.utc(
          task.startTime.year, task.startTime.month, task.startTime.day);
      if (_events[day] == null) {
        _events[day] = [];
      }
      _events[day]!.add(task);
    }
  }

  // Returns the list of tasks for a given day.
  List<Task> _getTasksForDay(DateTime day) {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    return _events[utcDay] ?? [];
  }

  // Called when the user taps on a day in the calendar.
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: NetworkImage('https://placehold.co/100x100/png'),
          ),
        ),
        title: const Text(
          'Calendar View',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
      ),
      // Listens for changes in the Hive box and rebuilds the UI.
      body: ValueListenableBuilder<Box<Task>>(
        valueListenable: tasksBox.listenable(),
        builder: (context, box, _) {
          _groupTasksByDay(); // Regroup tasks whenever the box changes
          // Post-frame callback to safely update the selected tasks list.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
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
                    borderRadius: BorderRadius.circular(30),
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
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.5),
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
                          "No tasks for this day.",
                          style: TextStyle(
                              color: AppColors.textLight, fontSize: 16),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final taskKey = task.key as int;
                        return TaskItem(task: task, taskKey: taskKey);
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
}
