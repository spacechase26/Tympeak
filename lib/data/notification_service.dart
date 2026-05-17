import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_10y.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {}

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    const taskChannel = AndroidNotificationChannel(
      'task_reminders',
      'Task Reminders',
      description: 'Reminders for your tasks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    const timerChannel = AndroidNotificationChannel(
      'timer_alerts_v2',
      'Timer Alerts',
      description: 'Pomodoro and countdown completions',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(taskChannel);
    await android?.createNotificationChannel(timerChannel);
  }

  static Future<void> requestPermissions() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  static const _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders', 'Task Reminders',
      importance: Importance.high, priority: Priority.high,
      playSound: true, enableVibration: true,
    ),
  );

  static const _timerDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'timer_alerts_v2', 'Timer Alerts',
      importance: Importance.max, priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      playSound: true, enableVibration: true,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    ),
  );

  // Try exact mode first; fall back to inexact if the OS denied exact alarms.
  static Future<void> _scheduleWithFallback(
      int id, String title, String body, tz.TZDateTime when, NotificationDetails details,
      {DateTimeComponents? match}) async {
    try {
      await _plugin.zonedSchedule(
        id, title, body, when, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match,
        );
      } catch (_) {}
    }
  }

  // Fire a notification N seconds from now.
  static Future<void> scheduleTimerAlert(
      int id, String title, String body, int secondsFromNow) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
    await _scheduleWithFallback(id, title, body, when, _timerDetails);
  }

  // One-time reminder on a specific date + time.
  static Future<void> scheduleReminder(
      int id, String taskText, String dueDateStr, String reminderTime) async {
    final dp = dueDateStr.split('-');
    final tp = reminderTime.split(':');
    if (dp.length != 3 || tp.length != 2) return;

    final scheduled = tz.TZDateTime(tz.local,
        int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]),
        int.parse(tp[0]), int.parse(tp[1]));
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _scheduleWithFallback(id, '📌 Task reminder', taskText, scheduled, _taskDetails);
  }

  // Weekly recurring reminder on a specific day of week + time.
  static Future<void> scheduleRecurring(
      int id, String taskText, int dayOfWeek, String reminderTime) async {
    final tp = reminderTime.split(':');
    if (tp.length != 2) return;
    final hour   = int.parse(tp[0]);
    final minute = int.parse(tp[1]);
    final targetWeekday = dayOfWeek + 1;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != targetWeekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _scheduleWithFallback(id, '🔁 Recurring task', taskText, scheduled, _taskDetails,
        match: DateTimeComponents.dayOfWeekAndTime);
  }

  static Future<void> cancel(int id) async {
    try { await _plugin.cancel(id); } catch (_) {}
  }

  static Future<void> cancelAll(List<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }
}
