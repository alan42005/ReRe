import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // Added this import
import 'package:reminder_app/models/task.dart';
import 'package:reminder_app/utils/app_colors.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Box<Task> tasksBox = Hive.box<Task>('tasks');

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
          'My Statistics',
          style:
              TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined,
                color: AppColors.textDark, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ValueListenableBuilder<Box<Task>>(
        valueListenable: tasksBox.listenable(),
        builder: (context, box, _) {
          final tasks = box.values.toList();
          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                "No statistics to show yet.\nAdd some tasks!",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight, fontSize: 16),
              ),
            );
          }

          // --- Calculate Statistics ---

          // 1. Weekly Chart Data
          final now = DateTime.now();
          final weeklyData = List.generate(7, (index) {
            final day = now.subtract(Duration(days: index));
            return tasks
                .where((task) =>
                    isSameDay(task.startTime, day) && task.isCompleted)
                .length
                .toDouble();
          }).reversed.toList();

          final double maxWeeklyValue = weeklyData.isEmpty
              ? 1
              : weeklyData.reduce((a, b) => a > b ? a : b);

          // 2. Overall Completion Stats
          final totalCompleted = tasks.where((t) => t.isCompleted).length;
          final overallRate = tasks.isNotEmpty
              ? (totalCompleted / tasks.length * 100).toInt()
              : 0;

          // 3. Most Frequent Reminder
          final reminderCounts = <int, int>{};
          for (var task in tasks) {
            if (task.reminderMinutesBefore != null &&
                task.reminderMinutesBefore! > 0) {
              reminderCounts.update(
                  task.reminderMinutesBefore!, (value) => value + 1,
                  ifAbsent: () => 1);
            }
          }
          final mostFrequentEntry = reminderCounts.entries.isEmpty
              ? null
              : reminderCounts.entries
                  .reduce((a, b) => a.value > b.value ? a : b);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Weekly Chart Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Completed Tasks (Last 7 Days)',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: WeeklyChart(
                          weeklyData: weeklyData, maxValue: maxWeeklyValue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Overall Completion Card
              StatInfoCard(
                title: 'Overall Completion Rate',
                value: '$overallRate%',
                subValue: '$totalCompleted / ${tasks.length} Tasks',
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 20),

              // Most Frequent Reminder Card
              StatInfoCard(
                title: 'Most Used Reminder',
                value: mostFrequentEntry != null
                    ? '${mostFrequentEntry.key} min before'
                    : 'N/A',
                subValue: mostFrequentEntry != null
                    ? '${mostFrequentEntry.value} times'
                    : 'No reminders set',
                icon: Icons.notifications_active_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

// Custom widget for the bar chart
class WeeklyChart extends StatelessWidget {
  final List<double> weeklyData;
  final double maxValue;
  const WeeklyChart(
      {super.key, required this.weeklyData, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue < 5
            ? 5
            : maxValue * 1.2, // Dynamic max Y, with a minimum of 5
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                const style = TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 14);
                final day =
                    DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(DateFormat.E().format(day)[0], style: style));
              },
              reservedSize: 28,
            ),
          ),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: weeklyData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                color: AppColors.accent,
                width: 15,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// Custom widget for the info cards on the stats page
class StatInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String subValue;
  final IconData icon;

  const StatInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.subValue,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 32),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textLight)),
                const SizedBox(height: 5),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(subValue,
              style: const TextStyle(
                  color: AppColors.textLight, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Helper function to check if two DateTime objects are on the same day.
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
