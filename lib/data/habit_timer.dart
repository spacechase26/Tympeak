import 'dart:async';
import 'package:flutter/material.dart';

// Singleton timer manager — survives tab switches
class HabitTimerManager {
  static final HabitTimerManager instance = HabitTimerManager._();
  HabitTimerManager._();

  final Map<String, _HTimer> _map = {};

  _HTimer _get(String key, int defaultSecs) =>
      _map.putIfAbsent(key, () => _HTimer(defaultSecs));

  ValueNotifier<_HTimerState> notifier(String key, int defaultSecs) =>
      _get(key, defaultSecs).notifier;

  bool isRunning(String key) => _map[key]?.notifier.value.running ?? false;

  void start(String key, int defaultSecs, VoidCallback onDone) =>
      _get(key, defaultSecs).start(onDone);

  void pause(String key) => _map[key]?.pause();

  void reset(String key, int secs) => _get(key, secs).reset(secs);
}

class _HTimerState {
  final int seconds;
  final bool running;
  const _HTimerState(this.seconds, {this.running = false});
}

class _HTimer {
  late ValueNotifier<_HTimerState> notifier;
  Timer? _timer;

  _HTimer(int secs) {
    notifier = ValueNotifier(_HTimerState(secs));
  }

  void start(VoidCallback onDone) {
    if (notifier.value.running || notifier.value.seconds <= 0) return;
    notifier.value = _HTimerState(notifier.value.seconds, running: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = notifier.value.seconds - 1;
      if (next <= 0) {
        _timer?.cancel();
        notifier.value = const _HTimerState(0, running: false);
        onDone();
      } else {
        notifier.value = _HTimerState(next, running: true);
      }
    });
  }

  void pause() {
    _timer?.cancel();
    notifier.value = _HTimerState(notifier.value.seconds, running: false);
  }

  void reset(int secs) {
    _timer?.cancel();
    notifier.value = _HTimerState(secs, running: false);
  }
}
