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
    print("NotificationService: Initializing...");
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
    print("NotificationService: Initialization complete.");

    // This function is called when the app starts.
    await _requestAndroidPermission();
  }

  // This method handles asking the user for the necessary permissions.
  Future<void> _requestAndroidPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      print("NotificationService: Requesting Android permissions...");
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // This line asks for the basic notification permission.
      final bool? notificationPermission =
          await androidImplementation?.requestNotificationsPermission();
      print(
          "NotificationService: Notification permission granted: $notificationPermission");

      // THIS IS THE LINE THAT ASKS FOR THE "ALARMS & REMINDERS" PERMISSION
      final bool? exactAlarmsPermission =
          await androidImplementation?.requestExactAlarmsPermission();
      print(
          "NotificationService: Exact alarms permission granted: $exactAlarmsPermission");
    }
  }

  Future<void> showTestNotification() async {
    print("NotificationService: Attempting to show a test notification...");
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'test_channel_id',
      'Test Notifications',
      channelDescription: 'Channel for testing notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
      999,
      'Test Notification',
      'If you see this, the notification system is working!',
      platformDetails,
    );
    print("NotificationService: show() method called for test notification.");
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    print(
        "NotificationService: Scheduling notification ID $id for: $scheduledTime");
    print("NotificationService: Current time is: ${DateTime.now()}");

    if (scheduledTime.isBefore(DateTime.now())) {
      print("NotificationService: CANCELED - Scheduled time is in the past.");
      return;
    }

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel_id',
          'Reminders',
          channelDescription: 'Channel for reminder notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    print("NotificationService: zonedSchedule() method called for ID $id.");
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
    print("NotificationService: Canceled notification ID $id.");
  }
}
