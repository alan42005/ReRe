import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'habit.g.dart';

@HiveType(typeId: 1)
class Habit extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String category;

  @HiveField(3)
  late int colorValue;

  @HiveField(4)
  late int iconCode;

  @HiveField(5)
  late List<String> completedDates; // Format: 'yyyy-MM-dd'

  @HiveField(6)
  late int targetPerDay;

  @HiveField(7)
  late DateTime createdAt;

  @HiveField(8)
  int? reminderMinuteOfDay;

  @HiveField(9)
  String? stackedAfterHabitId;

  Habit({
    required this.id,
    required this.title,
    this.category = 'General',
    this.colorValue = 0xFF5DC2B4,
    this.iconCode = 0xe59c, // Icons.star_rounded
    List<String>? completedDates,
    this.targetPerDay = 1,
    DateTime? createdAt,
    this.reminderMinuteOfDay,
    this.stackedAfterHabitId,
  })  : completedDates = completedDates ?? [],
        createdAt = createdAt ?? DateTime.now();

  static String formatDateKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  bool isCompletedOn(DateTime date) {
    final key = formatDateKey(date);
    return completedDates.contains(key);
  }

  void toggleCompletion(DateTime date) {
    final key = formatDateKey(date);
    if (completedDates.contains(key)) {
      completedDates.remove(key);
    } else {
      completedDates.add(key);
    }
    save();
  }

  int get currentStreak {
    if (completedDates.isEmpty) return 0;
    final now = DateTime.now();
    final todayKey = formatDateKey(now);
    final yesterdayKey = formatDateKey(now.subtract(const Duration(days: 1)));

    DateTime checkDate;
    if (completedDates.contains(todayKey)) {
      checkDate = now;
    } else if (completedDates.contains(yesterdayKey)) {
      checkDate = now.subtract(const Duration(days: 1));
    } else {
      return 0;
    }

    int streak = 0;
    while (completedDates.contains(formatDateKey(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get bestStreak {
    if (completedDates.isEmpty) return 0;
    final sortedDates = completedDates
        .map((e) => DateTime.tryParse(e))
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort();

    if (sortedDates.isEmpty) return 0;

    int maxStreak = 1;
    int current = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final prev = sortedDates[i - 1];
      final curr = sortedDates[i];
      if (curr.difference(prev).inDays == 1) {
        current++;
        if (current > maxStreak) {
          maxStreak = current;
        }
      } else if (curr.difference(prev).inDays > 1) {
        current = 1;
      }
    }
    return maxStreak;
  }

  double completionRateLastNDays(int n) {
    if (n <= 0) return 0.0;
    final now = DateTime.now();
    int count = 0;
    for (int i = 0; i < n; i++) {
      final day = now.subtract(Duration(days: i));
      if (isCompletedOn(day)) count++;
    }
    return count / n;
  }
}
