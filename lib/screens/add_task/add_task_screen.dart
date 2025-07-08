import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/notification_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _selectedReminder = 0;

  final List<Map<String, dynamic>> _reminderOptions = [
    {'value': 0, 'label': 'No reminder'},
    {'value': 5, 'label': '5 minutes before'},
    {'value': 10, 'label': '10 minutes before'},
    {'value': 15, 'label': '15 minutes before'},
    {'value': 30, 'label': '30 minutes before'},
    {'value': 60, 'label': '1 hour before'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _startTime = TimeOfDay.now();
    _endTime =
        TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _selectedDate)
      setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context,
      {bool isStartTime = true}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate != null && _startTime != null && _endTime != null) {
        final tasksBox = Hive.box<Task>('tasks');

        final finalStartTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );

        final finalEndTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );

        if (finalEndTime.isBefore(finalStartTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('End time must be after start time')),
          );
          return;
        }

        final newTask = Task(
          title: _titleController.text,
          startTime: finalStartTime,
          endTime: finalEndTime,
          isCompleted: false,
          reminderMinutesBefore: _selectedReminder,
        );

        final int taskKey = await tasksBox.add(newTask);

        // Schedule the main notification for the start time
        if (finalStartTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: taskKey,
            title: 'Task Starting!',
            body: _titleController.text,
            scheduledTime: finalStartTime,
          );
        } else {
          print(
              "Main notification not scheduled because start time is in the past.");
        }

        // Schedule the pre-task reminder notification
        if (_selectedReminder != null && _selectedReminder! > 0) {
          final reminderTime =
              finalStartTime.subtract(Duration(minutes: _selectedReminder!));
          if (reminderTime.isAfter(DateTime.now())) {
            await NotificationService().scheduleNotification(
              id: taskKey + 1000000,
              title: 'Reminder!',
              body:
                  "${_titleController.text} is starting in $_selectedReminder minutes.",
              scheduledTime: reminderTime,
            );
          } else {
            // FIX: Show a warning to the user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Reminder time of ${DateFormat.jm().format(reminderTime)} is in the past and was not scheduled.')),
            );
            print(
                "Reminder notification not scheduled because reminder time is in the past.");
          }
        }

        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Task'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Task Title', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 20),
              _buildDateTimePicker(
                label: 'Date',
                text: _selectedDate != null
                    ? DateFormat.yMMMd().format(_selectedDate!)
                    : 'Not Set',
                onPressed: () => _pickDate(context),
              ),
              const SizedBox(height: 20),
              _buildDateTimePicker(
                label: 'Start Time',
                text: _startTime != null
                    ? _startTime!.format(context)
                    : 'Not Set',
                onPressed: () => _pickTime(context, isStartTime: true),
              ),
              const SizedBox(height: 20),
              _buildDateTimePicker(
                label: 'End Time',
                text: _endTime != null ? _endTime!.format(context) : 'Not Set',
                onPressed: () => _pickTime(context, isStartTime: false),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: _selectedReminder,
                decoration: const InputDecoration(
                  labelText: 'Remind Me (before start)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notifications_active_outlined),
                ),
                items: _reminderOptions
                    .map((option) => DropdownMenuItem<int>(
                          value: option['value'],
                          child: Text(option['label']),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedReminder = value),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('Save Task'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker(
      {required String label,
      required String text,
      required VoidCallback onPressed}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        TextButton(
          onPressed: onPressed,
          child: Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent)),
        ),
      ],
    );
  }
}
