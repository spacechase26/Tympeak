import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

enum TimerTab { pomodoro, stopwatch, countdown }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with SingleTickerProviderStateMixin {
  TimerTab _tab = TimerTab.pomodoro;

  // Pomodoro
  static const _pomoDuration = 25 * 60;
  static const _breakDuration = 5 * 60;
  int _pomoSecondsLeft = _pomoDuration;
  bool _pomoRunning = false;
  bool _pomoBreak = false;
  int _pomoRounds = 0;
  Timer? _pomoTimer;

  // Stopwatch
  final _stopwatch = Stopwatch();
  Timer? _swTimer;
  Duration _swElapsed = Duration.zero;
  List<Duration> _laps = [];

  // Countdown
  int _cdMinutes = 10;
  int _cdSecondsLeft = 600;
  bool _cdRunning = false;
  Timer? _cdTimer;

  @override
  void dispose() {
    _pomoTimer?.cancel();
    _swTimer?.cancel();
    _cdTimer?.cancel();
    super.dispose();
  }

  // --- Pomodoro ---
  void _togglePomo() {
    if (_pomoRunning) {
      _pomoTimer?.cancel();
      setState(() => _pomoRunning = false);
    } else {
      setState(() => _pomoRunning = true);
      _pomoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (_pomoSecondsLeft > 0) {
            _pomoSecondsLeft--;
          } else {
            _pomoRunning = false;
            _pomoTimer?.cancel();
            if (!_pomoBreak) {
              _pomoRounds++;
              _pomoBreak = true;
              _pomoSecondsLeft = _breakDuration;
            } else {
              _pomoBreak = false;
              _pomoSecondsLeft = _pomoDuration;
            }
          }
        });
      });
    }
  }

  void _resetPomo() {
    _pomoTimer?.cancel();
    setState(() {
      _pomoRunning = false;
      _pomoBreak = false;
      _pomoSecondsLeft = _pomoDuration;
    });
  }

  // --- Stopwatch ---
  void _toggleSw() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _swTimer?.cancel();
    } else {
      _stopwatch.start();
      _swTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        setState(() => _swElapsed = _stopwatch.elapsed);
      });
    }
    setState(() {});
  }

  void _resetSw() {
    _stopwatch.stop();
    _stopwatch.reset();
    _swTimer?.cancel();
    setState(() {
      _swElapsed = Duration.zero;
      _laps = [];
    });
  }

  void _lapSw() {
    if (_stopwatch.isRunning) {
      setState(() => _laps.insert(0, _stopwatch.elapsed));
    }
  }

  // --- Countdown ---
  void _toggleCd() {
    if (_cdRunning) {
      _cdTimer?.cancel();
      setState(() => _cdRunning = false);
    } else {
      if (_cdSecondsLeft == 0) _cdSecondsLeft = _cdMinutes * 60;
      setState(() => _cdRunning = true);
      _cdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (_cdSecondsLeft > 0) {
            _cdSecondsLeft--;
          } else {
            _cdRunning = false;
            _cdTimer?.cancel();
          }
        });
      });
    }
  }

  void _resetCd() {
    _cdTimer?.cancel();
    setState(() {
      _cdRunning = false;
      _cdSecondsLeft = _cdMinutes * 60;
    });
  }

  String _fmt(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
    if (d.inHours > 0) return '$h:$m:$s';
    return '$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Timer', style: Theme.of(context).appBarTheme.titleTextStyle),
                ],
              ),
            ),
            _tabBar(),
            const SizedBox(height: 24),
            Expanded(child: _tabContent()),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: TimerTab.values.map((tab) {
            final selected = _tab == tab;
            final label = tab == TimerTab.pomodoro
                ? 'Pomodoro'
                : tab == TimerTab.stopwatch
                    ? 'Stopwatch'
                    : 'Countdown';
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? kPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white38,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case TimerTab.pomodoro:
        return _pomodoroContent();
      case TimerTab.stopwatch:
        return _stopwatchContent();
      case TimerTab.countdown:
        return _countdownContent();
    }
  }

  Widget _pomodoroContent() {
    final progress = _pomoSecondsLeft / (_pomoBreak ? _breakDuration : _pomoDuration);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              children: [
                Text(
                  _pomoBreak ? 'Break Time' : 'Focus',
                  style: TextStyle(color: kPurpleLight, fontSize: 13, letterSpacing: 1.5),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(kPurple),
                      ),
                      Text(
                        _fmt(_pomoSecondsLeft),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w200,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _circleBtn(Icons.refresh_rounded, _resetPomo, small: true),
                    const SizedBox(width: 20),
                    _circleBtn(
                      _pomoRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      _togglePomo,
                      large: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '$_pomoRounds round${_pomoRounds == 1 ? '' : 's'} completed',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopwatchContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              children: [
                Text(
                  _fmtDuration(_swElapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _circleBtn(Icons.flag_rounded, _lapSw, small: true),
                    const SizedBox(width: 20),
                    _circleBtn(
                      _stopwatch.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      _toggleSw,
                      large: true,
                    ),
                    const SizedBox(width: 20),
                    _circleBtn(Icons.stop_rounded, _resetSw, small: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _laps.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lap ${_laps.length - i}',
                          style: const TextStyle(color: Colors.white54)),
                      Text(_fmtDuration(_laps[i]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownContent() {
    final progress = _cdMinutes > 0 ? _cdSecondsLeft / (_cdMinutes * 60) : 1.0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_cdRunning && _cdSecondsLeft == _cdMinutes * 60) ...[
              const Text('Set duration', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white38),
                    onPressed: () => setState(() {
                      if (_cdMinutes > 1) {
                        _cdMinutes--;
                        _cdSecondsLeft = _cdMinutes * 60;
                      }
                    }),
                  ),
                  Text(
                    '$_cdMinutes min',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white38),
                    onPressed: () => setState(() {
                      _cdMinutes++;
                      _cdSecondsLeft = _cdMinutes * 60;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(kPurple),
                  ),
                  Text(
                    _fmt(_cdSecondsLeft),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circleBtn(Icons.refresh_rounded, _resetCd, small: true),
                const SizedBox(width: 20),
                _circleBtn(
                  _cdRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  _toggleCd,
                  large: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool large = false, bool small = false}) {
    final size = large ? 68.0 : small ? 48.0 : 56.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: large ? kPurple : Colors.white10,
          border: Border.all(color: large ? kPurple : Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: large ? 32 : 22),
      ),
    );
  }
}
