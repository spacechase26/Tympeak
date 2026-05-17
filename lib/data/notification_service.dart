import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_10y.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static String? lastError;

  // Reserved notification IDs — keep separate from task reminders.
  static const int kLiveTimerId = 900100;

  // Channel ID bumped to v4 to pick up the custom ding sound. Android
  // notification channels are immutable once created, so a fresh ID is
  // the only way to apply new sound / vibration / importance settings.
  static const String _timerChannel = 'timer_alerts_v4';
  static const _timerSound = RawResourceAndroidNotificationSound('ding');

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      lastError = 'tz init: $e';
    }

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
      _timerChannel,
      'Timer Alerts',
      description: 'Pomodoro / countdown completions and live timers',
      importance: Importance.max,
      playSound: true,
      sound: _timerSound,
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
    } catch (e) {
      lastError = 'permission: $e';
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  static const _taskDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders', 'Task Reminders',
      importance: Importance.high, priority: Priority.high,
      playSound: true, enableVibration: true,
    ),
  );

  // One-shot alert (segment transition, completion).
  static const _timerAlertDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _timerChannel, 'Timer Alerts',
      importance: Importance.max, priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      playSound: true, enableVibration: true,
      sound: _timerSound,
      visibility: NotificationVisibility.public,
    ),
  );

  // Live (ongoing) chronometer — silent updates via onlyAlertOnce.
  static NotificationDetails _liveDetails({
    required int baseTimeMs,
    required bool countDown,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannel, 'Timer Alerts',
        importance: Importance.high, priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        usesChronometer: true,
        chronometerCountDown: countDown,
        when: baseTimeMs,
        showWhen: true,
        playSound: false,
        enableVibration: false,
        visibility: NotificationVisibility.public,
      ),
    );
  }

  // Static (no chronometer) ongoing notification — used for the "paused" state.
  static NotificationDetails _liveStaticDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _timerChannel, 'Timer Alerts',
        importance: Importance.high, priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        visibility: NotificationVisibility.public,
      ),
    );
  }

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
    } catch (e) {
      lastError = 'exact: $e';
      try {
        await _plugin.zonedSchedule(
          id, title, body, when, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match,
        );
      } catch (e2) {
        lastError = 'exact+inexact: $e | $e2';
      }
    }
  }

  // ── Alert notifications (segment transitions, completions) ────────────────
  static Future<void> scheduleTimerAlert(
      int id, String title, String body, int secondsFromNow) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow));
    await _scheduleWithFallback(id, title, body, when, _timerAlertDetails);
  }

  static Future<void> showTimerAlertNow(int id, String title, String body) async {
    try {
      await _plugin.show(id, title, body, _timerAlertDetails);
    } catch (e) {
      lastError = 'show: $e';
    }
  }

  // ── Live chronometer (ongoing, silent updates) ────────────────────────────
  // baseTimeMs: epoch millis to count from (stopwatch) or to (countdown).
  static Future<void> showLiveChronometer({
    required String title,
    required String body,
    required int baseTimeMs,
    required bool countDown,
  }) async {
    try {
      await _plugin.show(
        kLiveTimerId, title, body,
        _liveDetails(baseTimeMs: baseTimeMs, countDown: countDown),
      );
    } catch (e) {
      lastError = 'live show: $e';
    }
  }

  // Schedule a future replacement of the live notification (used to swap the
  // chronometer base + title at Pomodoro segment boundaries).
  static Future<void> scheduleLiveChronometer({
    required String title,
    required String body,
    required int atSecondsFromNow,
    required int baseTimeMs,
    required bool countDown,
  }) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: atSecondsFromNow));
    await _scheduleWithFallback(
      kLiveTimerId, title, body, when,
      _liveDetails(baseTimeMs: baseTimeMs, countDown: countDown),
    );
  }

  static Future<void> showLiveStatic({
    required String title,
    required String body,
  }) async {
    try {
      await _plugin.show(kLiveTimerId, title, body, _liveStaticDetails());
    } catch (e) {
      lastError = 'live static: $e';
    }
  }

  static Future<void> cancelLive() async {
    await cancel(kLiveTimerId);
  }

  // ── Task reminders (separate channel, default sound) ─────────────────────
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

  // ── Cancel ────────────────────────────────────────────────────────────────
  static Future<void> cancel(int id) async {
    try { await _plugin.cancel(id); } catch (_) {}
  }

  static Future<void> cancelAll(List<int> ids) async {
    for (final id in ids) {
      await cancel(id);
    }
  }
}
