import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:reminder_app/models/task.dart';

class WidgetService {
  static Future<void> updatePrioritiesWidget() async {
    try {
      final now = DateTime.now();
      final dateStr = "Today - ${DateFormat.MMMd().format(now)}";

      if (!Hive.isBoxOpen('tasks')) {
        await Hive.openBox<Task>('tasks');
      }
      final box = Hive.box<Task>('tasks');

      final todayTasks = box.values.where((t) {
        return t.startTime.year == now.year &&
            t.startTime.month == now.month &&
            t.startTime.day == now.day &&
            !t.isCompleted;
      }).toList()
        ..sort((a, b) {
          if (a.priority != b.priority) {
            return a.priority.compareTo(b.priority);
          }
          return a.startTime.compareTo(b.startTime);
        });

      final p1 = todayTasks.isNotEmpty ? "1. ${todayTasks[0].title}" : "No pending priorities";
      final p2 = todayTasks.length > 1 ? "2. ${todayTasks[1].title}" : "";
      final p3 = todayTasks.length > 2 ? "3. ${todayTasks[2].title}" : "";

      await HomeWidget.saveWidgetData<String>('widget_date', dateStr);
      await HomeWidget.saveWidgetData<String>('widget_p1', p1);
      await HomeWidget.saveWidgetData<String>('widget_p2', p2);
      await HomeWidget.saveWidgetData<String>('widget_p3', p3);

      await HomeWidget.updateWidget(
        name: 'PriorityWidgetProvider',
        androidName: 'PriorityWidgetProvider',
      );
      debugPrint("WidgetService: Priority widget updated with ${todayTasks.length} tasks.");
    } catch (e) {
      debugPrint("WidgetService: Error updating widget: $e");
    }
  }
}
