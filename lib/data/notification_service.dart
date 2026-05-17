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

    const channel = AndroidNotificationChannel(
      'task_reminders',
      'Task Reminders',
      description: 'Reminders for your tasks',
      importance: Importance.high,
    );
    const timerChannel = AndroidNotificationChannel(
      'timer_alerts',
      'Timer Alerts',
      description: 'Pomodoro and countdown completions',
      importance: Importance.high,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
    await android?.createNotificationChannel(timerChannel);
  }

  // Fire a notification N seconds from now.
  static Future<void> scheduleTimerAlert(
      int id, String title, String body, int secondsFromNow) async {
    try {
      final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_alerts', 'Timer Alerts',
            importance: Importance.high, priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static Future<void> requestPermissions() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  // One-time reminder on a specific date + time.
  // dueDateStr: 'YYYY-MM-DD', reminderTime: 'HH:mm'
  static Future<void> scheduleReminder(
      int id, String taskText, String dueDateStr, String reminderTime) async {
    try {
      final dp = dueDateStr.split('-');
      final tp = reminderTime.split(':');
      if (dp.length != 3 || tp.length != 2) return;

      final scheduled = tz.TZDateTime(tz.local,
          int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]),
          int.parse(tp[0]), int.parse(tp[1]));
      if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

      await _plugin.zonedSchedule(
        id,
        '📌 Task reminder',
        taskText,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders', 'Task Reminders',
            importance: Importance.high, priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  // Weekly recurring reminder on a specific day of week + time.
  // dayOfWeek: 0=Mon … 6=Sun, reminderTime: 'HH:mm'
  static Future<void> scheduleRecurring(
      int id, String taskText, int dayOfWeek, String reminderTime) async {
    try {
      final tp = reminderTime.split(':');
      if (tp.length != 2) return;
      final hour   = int.parse(tp[0]);
      final minute = int.parse(tp[1]);

      // Dart weekday: 1=Mon … 7=Sun
      final targetWeekday = dayOfWeek + 1;
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

      // Advance to the next correct weekday that's in the future
      while (scheduled.weekday != targetWeekday || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id,
        '🔁 Recurring task',
        taskText,
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders', 'Task Reminders',
            importance: Importance.high, priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    try { await _plugin.cancel(id); } catch (_) {}
  }

  static Future<void> cancelAll(List<int> ids) async {
    for (final id in ids) await cancel(id);
  }
}
