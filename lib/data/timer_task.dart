import 'dart:convert';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'notification_service.dart';

// Shared key — main isolate writes the active timer state here, background
// isolate reads from it. Backed by SharedPreferences, which the plugin
// `reload()`s on every read so cross-isolate visibility is guaranteed.
const String kActiveTimerKey = 'active_timer';

// Commands sent from the main isolate to the background task handler.
const String kCmdReset   = 'reset';
const String kCmdRefresh = 'refresh';

// Notification ID ranges. Mirrored from timer_screen.dart — kept in sync
// so both isolates issue/cancel the same IDs.
const int kNotifBaseTimer    = 900000;
const int kNotifPomoComplete = kNotifBaseTimer + 9000;
const int kNotifCdComplete   = kNotifBaseTimer + 9999;

// Required to survive Dart tree-shaking. Without the pragma the symbol would
// be stripped from AOT release builds and the plugin's spawn would fail.
@pragma('vm:entry-point')
void startTimerTaskCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

class TimerTaskHandler extends TaskHandler {
  Map<String, dynamic>? _active;

  // Track last-known pomodoro segment so we only fire transition alerts once
  // per segment boundary instead of every tick.
  int  _lastPomoRound = 0;
  bool _lastPomoBreak = false;
  bool _livePosted    = false;
  bool _completed     = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await NotificationService.init();
    await _reloadActive();
    if (_active != null) {
      _tickAny(DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<void> _reloadActive() async {
    final raw = await FlutterForegroundTask.getData<String>(key: kActiveTimerKey);
    if (raw == null || raw.isEmpty) { _active = null; return; }
    try {
      _active = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      _active = null;
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    if (_completed) return;
    if (_active == null) {
      await _reloadActive();
      if (_active == null) {
        await FlutterForegroundTask.stopService();
        return;
      }
    }
    _tickAny(timestamp.millisecondsSinceEpoch);
  }

  void _tickAny(int nowMs) {
    switch (_active!['type'] as String?) {
      case 'pomodoro':  _tickPomo(nowMs); break;
      case 'countdown': _tickCd(nowMs);   break;
      case 'stopwatch': _tickSw(nowMs);   break;
    }
  }

  // ── Pomodoro ──────────────────────────────────────────────────────────────
  void _tickPomo(int nowMs) {
    final a         = _active!;
    final startedMs = a['startedMs'] as int;
    final focusSec  = a['focusSec']  as int;
    final breakSec  = a['breakSec']  as int;
    final loops     = a['loops']     as int;

    final elapsedSec = (nowMs - startedMs) ~/ 1000;

    int  cursor  = 0;
    int  round   = 1;
    bool inBreak = false;
    int  segLen  = focusSec;
    while (round <= loops) {
      segLen = inBreak ? breakSec : focusSec;
      if (elapsedSec < cursor + segLen) break;
      cursor += segLen;
      if (!inBreak) {
        if (round == loops) {
          _firePomoCompletion(loops);
          return;
        }
        inBreak = true;
      } else {
        inBreak = false;
        round++;
      }
    }

    final segEndMs   = startedMs + (cursor + segLen) * 1000;
    final newSegment = round != _lastPomoRound || inBreak != _lastPomoBreak;

    if (newSegment) {
      final wasFirstPost = !_livePosted;
      _lastPomoRound = round;
      _lastPomoBreak = inBreak;
      _livePosted    = true;

      NotificationService.showLiveChronometer(
        title: inBreak
            ? '☕ Break $round/${loops - 1}'
            : '🎯 Focus $round/$loops',
        body: 'Tympeak — Pomodoro running',
        baseTimeMs: segEndMs,
        countDown: true,
      );

      // Skip the audible alert on the very first segment (the user just
      // tapped play — they don't need a "back to focus" ping).
      final isInitialStart = wasFirstPost && round == 1 && !inBreak;
      if (!isInitialStart) {
        NotificationService.showTimerAlertNow(
          inBreak
              ? kNotifBaseTimer + round * 2
              : kNotifBaseTimer + (round - 1) * 2 + 1,
          inBreak ? '☕ Break time' : '🎯 Back to focus',
          'Round $round of $loops',
        );
      }
    }
  }

  void _firePomoCompletion(int loops) async {
    if (_completed) return;
    _completed = true;
    await NotificationService.cancelLive();
    await NotificationService.cancel(kNotifPomoComplete);
    await NotificationService.showTimerAlertNow(
      kNotifPomoComplete,
      '🎉 Pomodoro complete',
      '$loops rounds done. Great work!',
    );
    await FlutterForegroundTask.saveData(key: kActiveTimerKey, value: '');
    FlutterForegroundTask.sendDataToMain({'event': 'completed', 'type': 'pomodoro'});
    await FlutterForegroundTask.stopService();
  }

  // ── Countdown ─────────────────────────────────────────────────────────────
  void _tickCd(int nowMs) {
    final a         = _active!;
    final startedMs = a['startedMs'] as int;
    final totalSec  = a['totalSec']  as int;

    final elapsedSec = (nowMs - startedMs) ~/ 1000;
    final left       = totalSec - elapsedSec;

    if (left <= 0) {
      _fireCdCompletion();
      return;
    }

    if (!_livePosted) {
      _livePosted = true;
      final endMs = startedMs + totalSec * 1000;
      NotificationService.showLiveChronometer(
        title: '⏰ Countdown',
        body: 'Tympeak — running',
        baseTimeMs: endMs,
        countDown: true,
      );
    }
  }

  void _fireCdCompletion() async {
    if (_completed) return;
    _completed = true;
    await NotificationService.cancelLive();
    await NotificationService.cancel(kNotifCdComplete);
    await NotificationService.showTimerAlertNow(
      kNotifCdComplete,
      '⏰ Time\'s up',
      'Countdown complete',
    );
    await FlutterForegroundTask.saveData(key: kActiveTimerKey, value: '');
    FlutterForegroundTask.sendDataToMain({'event': 'completed', 'type': 'countdown'});
    await FlutterForegroundTask.stopService();
  }

  // ── Stopwatch ─────────────────────────────────────────────────────────────
  // Doesn't complete on its own — just keeps the live notification accurate.
  void _tickSw(int nowMs) {
    final a         = _active!;
    final paused    = a['paused']  == true;
    final startedMs = a['startedMs'] as int;
    final priorMs   = (a['priorMs'] as int?) ?? 0;

    if (!_livePosted) {
      _livePosted = true;
      if (paused) {
        NotificationService.showLiveStatic(
          title: '⏱ Stopwatch paused',
          body:  '${_fmtMs(priorMs)} elapsed — tap to resume',
        );
      } else {
        // Chronometer base = (now - elapsed), counts up from there.
        final chronometerBaseMs = startedMs - priorMs;
        NotificationService.showLiveChronometer(
          title: '⏱ Stopwatch',
          body:  'Tympeak — running',
          baseTimeMs: chronometerBaseMs,
          countDown: false,
        );
      }
    }
  }

  String _fmtMs(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Commands from main isolate ────────────────────────────────────────────
  @override
  void onReceiveData(Object data) async {
    if (data is! Map) return;
    final cmd = data['cmd'] as String?;
    if (cmd == kCmdReset) {
      await _cancelAllTimerNotifs();
      await FlutterForegroundTask.saveData(key: kActiveTimerKey, value: '');
      _active = null;
      _completed = true;
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } else if (cmd == kCmdRefresh) {
      // State changed (stopwatch pause/resume/lap) — re-read and re-post the
      // live notification so the chronometer base updates.
      await _reloadActive();
      _livePosted    = false;
      _lastPomoRound = 0;
      _lastPomoBreak = false;
      _completed     = false;
      if (_active != null) {
        _tickAny(DateTime.now().millisecondsSinceEpoch);
      }
    }
  }

  Future<void> _cancelAllTimerNotifs() async {
    await NotificationService.cancelLive();
    await NotificationService.cancel(kNotifPomoComplete);
    await NotificationService.cancel(kNotifCdComplete);
    // Pomodoro transition alerts: IDs 900002..900030 for up to 12 loops.
    for (int i = 0; i < 32; i++) {
      await NotificationService.cancel(kNotifBaseTimer + i);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Live chronometer always goes when the service stops, regardless of why.
    // Completion alerts have their own IDs and are unaffected.
    await NotificationService.cancelLive();
  }
}
