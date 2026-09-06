import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:reminder_app/main.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/notification_service.dart';
import 'package:reminder_app/utils/widget_service.dart';

class AddTaskScreen extends StatefulWidget {
  final DateTime? initialDate;

  const AddTaskScreen({super.key, this.initialDate});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _selectedReminder = 0;
  int _selectedPriority = 2; // 1 = High/Top, 2 = Medium, 3 = Low

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
    _selectedDate = widget.initialDate ?? DateTime.now();
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
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
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
          title: _titleController.text.trim(),
          startTime: finalStartTime,
          endTime: finalEndTime,
          isCompleted: false,
          reminderMinutesBefore: _selectedReminder,
          priority: _selectedPriority,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
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
                  "${_titleController.text} starts in $_selectedReminder minutes.",
              scheduledTime: reminderTime,
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Reminder time of ${DateFormat.jm().format(reminderTime)} was in the past.')),
            );
          }
        }

        HapticFeedback.mediumImpact();
        await WidgetService.updatePrioritiesWidget();
        MainScreen.switchToTab(0);

        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add to Daily Planner',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Task or Time-Block Title',
                  hintText: 'e.g. Deep Work on Project, Team Sync',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 18),

              // Priority Selector (1 = Top Priority, 2 = Medium, 3 = Low)
              const Text('Priority Level',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityChip(1, 'Top Priority ⭐', AppColors.priorityHigh),
                  const SizedBox(width: 8),
                  _buildPriorityChip(2, 'Medium', AppColors.priorityMedium),
                  const SizedBox(width: 8),
                  _buildPriorityChip(3, 'Low', AppColors.priorityLow),
                ],
              ),
              const SizedBox(height: 20),

              // Date & Time pickers
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    _buildDateTimePicker(
                      label: 'Date',
                      text: _selectedDate != null
                          ? DateFormat.yMMMd().format(_selectedDate!)
                          : 'Not Set',
                      icon: Icons.calendar_today_rounded,
                      onPressed: () => _pickDate(context),
                    ),
                    const Divider(height: 24),
                    _buildDateTimePicker(
                      label: 'Start Time',
                      text: _startTime != null
                          ? _startTime!.format(context)
                          : 'Not Set',
                      icon: Icons.access_time_rounded,
                      onPressed: () => _pickTime(context, isStartTime: true),
                    ),
                    const Divider(height: 24),
                    _buildDateTimePicker(
                      label: 'End Time',
                      text: _endTime != null
                          ? _endTime!.format(context)
                          : 'Not Set',
                      icon: Icons.timer_outlined,
                      onPressed: () => _pickTime(context, isStartTime: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reminder Dropdown
              DropdownButtonFormField<int>(
                value: _selectedReminder,
                decoration: InputDecoration(
                  labelText: 'Reminder before start',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  prefixIcon: const Icon(Icons.notifications_active_outlined),
                ),
                items: _reminderOptions
                    .map((option) => DropdownMenuItem<int>(
                          value: option['value'],
                          child: Text(option['label']),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedReminder = value),
              ),
              const SizedBox(height: 20),

              // Optional Notes Field
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes or Key Deliverables (Optional)',
                  hintText: 'Add sub-points, links, or context...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                child: const Text('Add to Schedule'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(int level, String label, Color color) {
    final isSelected = _selectedPriority == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : AppColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textLight),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(text,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark)),
        ),
      ],
    );
  }
}
