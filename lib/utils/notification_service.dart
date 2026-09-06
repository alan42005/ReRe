import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _notificationService =
      NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    debugPrint("NotificationService: Initializing...");
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    tz.initializeTimeZones();

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create high-priority Notification Channels for Android 8.0+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      const AndroidNotificationChannel reminderChannel =
          AndroidNotificationChannel(
        'reminder_channel_id',
        'Daily Reminders & Tasks',
        description: 'Time-sensitive task reminders and alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const AndroidNotificationChannel focusChannel =
          AndroidNotificationChannel(
        'focus_channel',
        'Focus Timer Sessions',
        description: 'Notifications when deep work or pomodoro sessions complete',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation.createNotificationChannel(reminderChannel);
      await androidImplementation.createNotificationChannel(focusChannel);
      debugPrint("NotificationService: Notification channels registered.");
    }

    await _requestAndroidPermission();
    debugPrint("NotificationService: Initialization complete.");
  }

  Future<void> _requestAndroidPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      debugPrint("NotificationService: Requesting Android permissions...");
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? notificationPermission =
          await androidImplementation?.requestNotificationsPermission();
      debugPrint(
          "NotificationService: Notification permission granted: $notificationPermission");

      final bool? exactAlarmsPermission =
          await androidImplementation?.requestExactAlarmsPermission();
      debugPrint(
          "NotificationService: Exact alarms permission granted: $exactAlarmsPermission");
    }
  }

  Future<void> showTestNotification() async {
    debugPrint("NotificationService: Showing test notification...");
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel_id',
      'Daily Reminders & Tasks',
      channelDescription: 'Time-sensitive task reminders and alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      999,
      'ReRe Notification System Active! 🔔',
      'Your reminders and timers are ready and configured.',
      platformDetails,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final durationUntil = scheduledTime.difference(DateTime.now());

    if (durationUntil.isNegative) {
      debugPrint("NotificationService: CANCELED - Scheduled time is in the past: $scheduledTime");
      return;
    }

    // Mathematically exact target time in local timezone
    final tzTarget = tz.TZDateTime.now(tz.local).add(durationUntil);

    debugPrint("NotificationService: Scheduling ID $id for $tzTarget (in ${durationUntil.inMinutes}m)");

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel_id',
        'Daily Reminders & Tasks',
        channelDescription: 'Time-sensitive task reminders and alerts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzTarget,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint("NotificationService: Successfully scheduled notification ID $id.");
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    debugPrint("NotificationService: Canceled notification ID $id.");
  }
}
