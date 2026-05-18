import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'timer_task.dart';

/// Wrapper around the `flutter_foreground_task` plugin. The plugin runs the
/// timer logic in a *separate* Dart isolate (spawned by the foreground
/// service), which survives the main isolate being killed when the user
/// swipes the app from recents on aggressive OEMs (MIUI, OneUI, etc.).
///
/// Main isolate writes the active-timer state via [start] / [update], and
/// the background `TimerTaskHandler` reads it through the plugin's shared
/// storage. [stop] tears the service down on reset / completion.
class TimerKeepAlive {
  static const int _kServiceId = 900099;

  static Future<void> start(Map<String, dynamic> active) async {
    await FlutterForegroundTask.saveData(
      key: kActiveTimerKey,
      value: jsonEncode(active),
    );
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'cmd': kCmdRefresh});
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _kServiceId,
      notificationTitle: 'Tympeak — timer active',
      notificationText:  'Keeps your timer accurate when the screen is off.',
      callback: startTimerTaskCallback,
    );
  }

  /// Push a state change (eg. stopwatch pause/resume/lap) without restarting
  /// the service. The handler re-reads `active_timer` and re-posts the live
  /// notification with the new chronometer base.
  static Future<void> update(Map<String, dynamic> active) async {
    await FlutterForegroundTask.saveData(
      key: kActiveTimerKey,
      value: jsonEncode(active),
    );
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'cmd': kCmdRefresh});
    }
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.saveData(key: kActiveTimerKey, value: '');
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
