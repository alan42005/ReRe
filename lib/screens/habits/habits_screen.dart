import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/models/habit.dart';
import 'package:reminder_app/screens/habits/add_habit_dialog.dart';
import 'package:reminder_app/utils/app_colors.dart';
import 'package:reminder_app/utils/habit_icon_helper.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final Box<Habit> habitsBox = Hive.box<Habit>('habits');

  void _openAddHabitDialog([Habit? habit]) {
    showDialog(
      context: context,
      builder: (context) => AddHabitDialog(habitToEdit: habit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Habit Tracker',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            tooltip: 'Add Habit',
            onPressed: () => _openAddHabitDialog(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ValueListenableBuilder<Box<Habit>>(
        valueListenable: habitsBox.listenable(),
        builder: (context, box, _) {
          final habits = box.values.toList();
          final completedToday =
              habits.where((h) => h.isCompletedOn(today)).length;
          final totalHabits = habits.length;
          final overallBestStreak = habits.isEmpty
              ? 0
              : habits
                  .map((h) => h.bestStreak)
                  .reduce((a, b) => a > b ? a : b);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Summary Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Today Done',
                        value: '$completedToday / $totalHabits',
                        icon: Icons.check_circle_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Best Streak',
                        value: '$overallBestStreak Days',
                        icon: Icons.local_fire_department_rounded,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Consistency Heatmap Graph
                _buildConsistencyHeatmap(habits),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Habits',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      DateFormat.MMMMd().format(today),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (habits.isEmpty)
                  _buildEmptyState()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: habits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final habit = habits[index];
                      return _buildHabitCard(habit, today);
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyHeatmap(List<Habit> habits) {
    final now = DateTime.now();
    // 35 days (5 weeks)
    final days = List.generate(35, (i) => now.subtract(Duration(days: 34 - i)));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consistency Grid (Last 5 Weeks)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Icon(Icons.insights_rounded,
                  color: AppColors.textLight, size: 18),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: 35,
            itemBuilder: (context, index) {
              final day = days[index];
              final completedCount =
                  habits.where((h) => h.isCompletedOn(day)).length;
              final isToday = Habit.formatDateKey(day) ==
                  Habit.formatDateKey(DateTime.now());

              Color cellColor = Colors.grey.shade100;
              if (habits.isNotEmpty && completedCount > 0) {
                final ratio = completedCount / habits.length;
                if (ratio >= 0.75) {
                  cellColor = const Color(0xFF2ED573);
                } else if (ratio >= 0.4) {
                  cellColor = const Color(0xFF7BED9F);
                } else {
                  cellColor = const Color(0xFFB8E994);
                }
              }

              return Tooltip(
                message:
                    '${DateFormat.MMMd().format(day)}: $completedCount habits completed',
                child: Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(6),
                    border: isToday
                        ? Border.all(color: Colors.black, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      day.day.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.w500,
                        color: completedCount > 0
                            ? Colors.black87
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              const SizedBox(width: 4),
              _legendBox(Colors.grey.shade200),
              _legendBox(const Color(0xFFB8E994)),
              _legendBox(const Color(0xFF7BED9F)),
              _legendBox(const Color(0xFF2ED573)),
              const SizedBox(width: 4),
              const Text('More',
                  style: TextStyle(fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHabitCard(Habit habit, DateTime today) {
    final isDoneToday = habit.isCompletedOn(today);
    final habitColor = Color(habit.colorValue);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDoneToday
              ? habitColor.withValues(alpha: 0.5)
              : AppColors.cardBorder,
          width: isDoneToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: habitColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  HabitIconHelper.getIcon(habit.iconCode),
                  color: habitColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        decoration: isDoneToday
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            habit.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded,
                                size: 16, color: Colors.orange),
                            Text(
                              '${habit.currentStreak} streak',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Complete button
              GestureDetector(
                onTap: () => setState(() => habit.toggleCompletion(today)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDoneToday ? habitColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDoneToday ? habitColor : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: isDoneToday
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : null,
                ),
              ),
              PopupMenuButton<String>(
                icon:
                    const Icon(Icons.more_vert_rounded, color: AppColors.textLight),
                onSelected: (value) {
                  if (value == 'edit') {
                    _openAddHabitDialog(habit);
                  } else if (value == 'delete') {
                    habit.delete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mini 7-day strip
          _build7DayStrip(habit),
        ],
      ),
    );
  }

  Widget _build7DayStrip(Habit habit) {
    final now = DateTime.now();
    // Mon to Sun or last 7 days
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isDone = habit.isCompletedOn(day);
          final isToday = Habit.formatDateKey(day) ==
              Habit.formatDateKey(DateTime.now());

          return Column(
            children: [
              Text(
                DateFormat.E().format(day)[0],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isToday ? Colors.black : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? Color(habit.colorValue)
                      : Colors.grey.shade200,
                  border: isToday
                      ? Border.all(color: Colors.black, width: 1)
                      : null,
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : null,
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 36, color: AppColors.textDark),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Habits Tracked Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first daily habit like "Morning Meditation" or "Read 15 Pages" to begin building streaks!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openAddHabitDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add My First Habit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
