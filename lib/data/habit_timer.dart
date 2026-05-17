import 'dart:async';
import 'package:flutter/material.dart';

// Singleton timer manager — survives tab switches
class HabitTimerManager {
  static final HabitTimerManager instance = HabitTimerManager._();
  HabitTimerManager._();

  final Map<String, _HTimer> _map = {};

  _HTimer _get(String key, int defaultSecs) =>
      _map.putIfAbsent(key, () => _HTimer(defaultSecs));

  ValueNotifier<HTimerState> notifier(String key, int defaultSecs) =>
      _get(key, defaultSecs).notifier;

  bool isRunning(String key) => _map[key]?.notifier.value.running ?? false;

  void start(String key, int defaultSecs, VoidCallback onDone) =>
      _get(key, defaultSecs).start(onDone);

  void pause(String key) => _map[key]?.pause();

  void reset(String key, int secs) => _get(key, secs).reset(secs);
}

class HTimerState {
  final int seconds;
  final bool running;
  const HTimerState(this.seconds, {this.running = false});
}

// Internal — not part of the public API
// ignore_for_file: library_private_types_in_public_api


class _HTimer {
  late ValueNotifier<HTimerState> notifier;
  Timer? _timer;

  _HTimer(int secs) {
    notifier = ValueNotifier(HTimerState(secs));
  }

  void start(VoidCallback onDone) {
    if (notifier.value.running || notifier.value.seconds <= 0) return;
    notifier.value = HTimerState(notifier.value.seconds, running: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = notifier.value.seconds - 1;
      if (next <= 0) {
        _timer?.cancel();
        notifier.value = const HTimerState(0, running: false);
        onDone();
      } else {
        notifier.value = HTimerState(next, running: true);
      }
    });
  }

  void pause() {
    _timer?.cancel();
    notifier.value = HTimerState(notifier.value.seconds, running: false);
  }

  void reset(int secs) {
    _timer?.cancel();
    notifier.value = HTimerState(secs, running: false);
  }
}
