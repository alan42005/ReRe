import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  late String title;

  // Renamed from dueDate to endTime for clarity
  @HiveField(1)
  late DateTime endTime;

  @HiveField(2)
  late bool isCompleted;

  @HiveField(3)
  String? category;

  @HiveField(4)
  int? reminderMinutesBefore;

  // New field for the task's start time
  @HiveField(5)
  late DateTime startTime;

  Task({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isCompleted = false,
    this.category,
    this.reminderMinutesBefore,
  });
}
