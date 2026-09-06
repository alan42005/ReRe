import 'package:hive/hive.dart';

part 'focus_session.g.dart';

@HiveType(typeId: 2)
class FocusSession extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late int durationMinutes;

  @HiveField(3)
  late String mode; // 'pomodoro' or 'stopwatch'

  @HiveField(4)
  late DateTime completedAt;

  @HiveField(5)
  String? linkedCategory;

  FocusSession({
    required this.id,
    required this.title,
    required this.durationMinutes,
    this.mode = 'pomodoro',
    DateTime? completedAt,
    this.linkedCategory,
  }) : completedAt = completedAt ?? DateTime.now();
}
