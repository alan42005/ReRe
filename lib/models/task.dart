import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  late String title;

  @HiveField(1)
  late DateTime endTime;

  @HiveField(2)
  late bool isCompleted;

  @HiveField(3)
  String? category;

  @HiveField(4)
  int? reminderMinutesBefore;

  @HiveField(5)
  late DateTime startTime;

  @HiveField(6)
  int priority; // 1 = Top Priority (Must Do), 2 = Medium, 3 = Low

  @HiveField(7)
  String? notes;

  @HiveField(8)
  int focusMinutesSpent;

  Task({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isCompleted = false,
    this.category,
    this.reminderMinutesBefore,
    this.priority = 2,
    this.notes,
    this.focusMinutesSpent = 0,
  });

  bool get isTopPriority => priority == 1;
}
