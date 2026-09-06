import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/models/focus_session.dart';
import 'package:reminder_app/models/habit.dart';
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/utils/app_colors.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final Box<Task> tasksBox = Hive.box<Task>('tasks');
  final Box<Habit> habitsBox = Hive.box<Habit>('habits');
  final Box<FocusSession> focusBox = Hive.box<FocusSession>('focus_logs');
  final Box settingsBox = Hive.box('settings');

  void _exportLocalBackup() {
    try {
      final tasksData = tasksBox.values.map((t) => {
            'title': t.title,
            'startTime': t.startTime.toIso8601String(),
            'endTime': t.endTime.toIso8601String(),
            'isCompleted': t.isCompleted,
            'category': t.category,
            'priority': t.priority,
            'notes': t.notes,
            'focusMinutesSpent': t.focusMinutesSpent,
          }).toList();

      final habitsData = habitsBox.values.map((h) => {
            'id': h.id,
            'title': h.title,
            'category': h.category,
            'colorValue': h.colorValue,
            'iconCode': h.iconCode,
            'completedDates': h.completedDates,
            'targetPerDay': h.targetPerDay,
            'createdAt': h.createdAt.toIso8601String(),
          }).toList();

      final focusData = focusBox.values.map((f) => {
            'id': f.id,
            'title': f.title,
            'durationMinutes': f.durationMinutes,
            'mode': f.mode,
            'completedAt': f.completedAt.toIso8601String(),
          }).toList();

      final backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'userName': settingsBox.get('userName', defaultValue: 'User'),
        'tasks': tasksData,
        'habits': habitsData,
        'focus_logs': focusData,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: AppColors.accent),
              SizedBox(width: 8),
              Text('Local Backup JSON'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All your planner tasks, habits, and focus logs have been compiled into this offline JSON backup. You can copy it to save it safely anywhere.',
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              Container(
                height: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonString));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy to Clipboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textDark,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _importLocalBackup() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restore from Local Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your previously exported JSON backup here to restore your tasks, habits, and focus sessions.',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Paste backup JSON string here...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final Map<String, dynamic> data = jsonDecode(controller.text);
                if (data['tasks'] != null) {
                  for (var item in data['tasks']) {
                    tasksBox.add(Task(
                      title: item['title'] ?? 'Task',
                      startTime: DateTime.parse(item['startTime']),
                      endTime: DateTime.parse(item['endTime']),
                      isCompleted: item['isCompleted'] ?? false,
                      category: item['category'],
                      priority: item['priority'] ?? 2,
                      notes: item['notes'],
                      focusMinutesSpent: item['focusMinutesSpent'] ?? 0,
                    ));
                  }
                }
                if (data['habits'] != null) {
                  for (var item in data['habits']) {
                    habitsBox.add(Habit(
                      id: item['id'] ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      title: item['title'] ?? 'Habit',
                      category: item['category'] ?? 'General',
                      colorValue: item['colorValue'] ?? 0xFF5DC2B4,
                      iconCode: item['iconCode'] ?? 0xe59c,
                      completedDates:
                          List<String>.from(item['completedDates'] ?? []),
                      targetPerDay: item['targetPerDay'] ?? 1,
                      createdAt: item['createdAt'] != null
                          ? DateTime.parse(item['createdAt'])
                          : DateTime.now(),
                    ));
                  }
                }
                if (data['focus_logs'] != null) {
                  for (var item in data['focus_logs']) {
                    focusBox.add(FocusSession(
                      id: item['id'] ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      title: item['title'] ?? 'Deep Work',
                      durationMinutes: item['durationMinutes'] ?? 25,
                      mode: item['mode'] ?? 'pomodoro',
                      completedAt: item['completedAt'] != null
                          ? DateTime.parse(item['completedAt'])
                          : DateTime.now(),
                    ));
                  }
                }
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Backup data restored successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid backup JSON: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textDark,
            ),
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Insights & Privacy',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          tasksBox.listenable(),
          habitsBox.listenable(),
          focusBox.listenable(),
        ]),
        builder: (context, _) {
          final tasks = tasksBox.values.toList();
          final habits = habitsBox.values.toList();
          final focusLogs = focusBox.values.toList();

          final today = DateTime.now();

          // Calculate Daily Harmony Score (0 - 100)
          final todayTasks = tasks
              .where((t) =>
                  t.startTime.year == today.year &&
                  t.startTime.month == today.month &&
                  t.startTime.day == today.day)
              .toList();

          final taskCompletionRatio = todayTasks.isNotEmpty
              ? todayTasks.where((t) => t.isCompleted).length / todayTasks.length
              : 1.0;

          final habitCompletionRatio = habits.isNotEmpty
              ? habits.where((h) => h.isCompletedOn(today)).length /
                  habits.length
              : 1.0;

          final todayFocusMinutes = focusLogs
              .where((f) =>
                  f.completedAt.year == today.year &&
                  f.completedAt.month == today.month &&
                  f.completedAt.day == today.day)
              .fold<int>(0, (sum, item) => sum + item.durationMinutes);

          // Target 60 mins focus per day for 100%
          final focusTargetRatio = (todayFocusMinutes / 60).clamp(0.0, 1.0);

          final harmonyScore = ((taskCompletionRatio * 40) +
                  (habitCompletionRatio * 35) +
                  (focusTargetRatio * 25))
              .round()
              .clamp(0, 100);

          // Weekly Focus Chart Data (Last 7 Days)
          final weeklyFocusData = List.generate(7, (index) {
            final day = today.subtract(Duration(days: 6 - index));
            final mins = focusLogs
                .where((f) =>
                    f.completedAt.year == day.year &&
                    f.completedAt.month == day.month &&
                    f.completedAt.day == day.day)
                .fold<int>(0, (sum, f) => sum + f.durationMinutes);
            return mins.toDouble();
          });

          final maxFocusMinutes = weeklyFocusData.isEmpty
              ? 60.0
              : weeklyFocusData.reduce((a, b) => a > b ? a : b);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Harmony Score Banner
                _buildHarmonyScoreCard(harmonyScore, todayFocusMinutes),
                const SizedBox(height: 20),

                // Weekly Focus Minutes Chart
                _buildWeeklyFocusChart(weeklyFocusData, maxFocusMinutes),
                const SizedBox(height: 20),

                // Habit Momentum Overview
                _buildHabitMomentumCard(habits),
                const SizedBox(height: 24),

                // 100% Local Privacy & Backup Section
                const Text(
                  '100% Private On-Device Storage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                _buildPrivacyAndBackupCard(),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHarmonyScoreCard(int score, int focusMins) {
    String message = 'Building Momentum';
    Color badgeColor = AppColors.primary;

    if (score >= 80) {
      message = 'Peak Flow State 🚀';
      badgeColor = AppColors.priorityLow;
    } else if (score >= 50) {
      message = 'Steady Progress ⚡';
      badgeColor = AppColors.priorityMedium;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeColor.withValues(alpha: 0.2),
              border: Border.all(color: badgeColor, width: 3),
            ),
            child: Center(
              child: Text(
                '$score',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Harmony Score',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Calculated from your daily planner, completed habits, and $focusMins min focus.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyFocusChart(List<double> data, double maxValue) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                'Focus Minutes (Last 7 Days)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              Icon(Icons.timer_outlined, color: AppColors.accent, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue < 30 ? 30 : maxValue * 1.25,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double val, TitleMeta meta) {
                        final day = DateTime.now()
                            .subtract(Duration(days: 6 - val.toInt()));
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            DateFormat.E().format(day)[0],
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                      reservedSize: 26,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: entry.value > 0
                            ? AppColors.pomodoroWork
                            : Colors.grey.shade300,
                        width: 14,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitMomentumCard(List<Habit> habits) {
    final total = habits.length;
    final bestStreak = habits.isEmpty
        ? 0
        : habits.map((h) => h.bestStreak).reduce((a, b) => a > b ? a : b);
    final activeStreaks = habits.where((h) => h.currentStreak > 0).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Habit Consistency Momentum',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricColumn('Active Habits', '$total'),
              Container(height: 32, width: 1, color: Colors.grey.shade200),
              _metricColumn('Active Streaks', '$activeStreaks'),
              Container(height: 32, width: 1, color: Colors.grey.shade200),
              _metricColumn('Longest Streak', '$bestStreak Days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, String val) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }

  Widget _buildPrivacyAndBackupCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero Cloud. Zero Tracking.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'All personal data stays 100% on your device.',
                      style: TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportLocalBackup,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export JSON'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textDark,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importLocalBackup,
                  icon: const Icon(Icons.upload_rounded, size: 18),
                  label: const Text('Restore Backup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
