import 'package:flutter/services.dart';

/// Thin wrapper around the native foreground service. Call `start()` whenever
/// a user-facing timer becomes active and `stop()` when it ends or resets.
/// While the service is running the OS keeps the app process resident, so
/// the Dart isolate's periodic timers continue firing even when the screen
/// is locked or the app has been swiped from recents.
class TimerKeepAlive {
  static const _ch = MethodChannel('com.spacechase.tympeak/keepalive');

  static Future<void> start() async {
    try { await _ch.invokeMethod('start'); } catch (_) {}
  }

  static Future<void> stop() async {
    try { await _ch.invokeMethod('stop'); } catch (_) {}
  }
}
