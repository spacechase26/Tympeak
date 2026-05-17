import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

enum TimerTab { pomodoro, stopwatch, countdown }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with TickerProviderStateMixin {
  TimerTab _tab = TimerTab.pomodoro;

  // Pomodoro
  static const _pomoDuration = 25 * 60;
  static const _breakDuration = 5 * 60;
  int _pomoSecondsLeft = _pomoDuration;
  bool _pomoRunning = false;
  bool _pomoBreak = false;
  int _pomoRounds = 0;
  Timer? _pomoTimer;
  late AnimationController _pomoAnim;

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
  void initState() {
    super.initState();
    _pomoAnim = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _pomoTimer?.cancel();
    _swTimer?.cancel();
    _cdTimer?.cancel();
    _pomoAnim.dispose();
    super.dispose();
  }

  void _togglePomo() {
    if (_pomoRunning) {
      _pomoTimer?.cancel();
      _pomoAnim.stop();
      setState(() => _pomoRunning = false);
    } else {
      setState(() => _pomoRunning = true);
      _pomoAnim.repeat();
      _pomoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (_pomoSecondsLeft > 0) {
            _pomoSecondsLeft--;
          } else {
            _pomoRunning = false;
            _pomoTimer?.cancel();
            _pomoAnim.stop();
            if (!_pomoBreak) { _pomoRounds++; _pomoBreak = true; _pomoSecondsLeft = _breakDuration; }
            else { _pomoBreak = false; _pomoSecondsLeft = _pomoDuration; }
          }
        });
      });
    }
  }

  void _resetPomo() {
    _pomoTimer?.cancel();
    _pomoAnim.stop();
    setState(() { _pomoRunning = false; _pomoBreak = false; _pomoSecondsLeft = _pomoDuration; });
  }

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
    setState(() { _swElapsed = Duration.zero; _laps = []; });
  }

  void _lapSw() {
    if (_stopwatch.isRunning) setState(() => _laps.insert(0, _stopwatch.elapsed));
  }

  void _toggleCd() {
    if (_cdRunning) {
      _cdTimer?.cancel();
      setState(() => _cdRunning = false);
    } else {
      if (_cdSecondsLeft == 0) _cdSecondsLeft = _cdMinutes * 60;
      setState(() => _cdRunning = true);
      _cdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          if (_cdSecondsLeft > 0) { _cdSecondsLeft--; }
          else { _cdRunning = false; _cdTimer?.cancel(); }
        });
      });
    }
  }

  void _resetCd() {
    _cdTimer?.cancel();
    setState(() { _cdRunning = false; _cdSecondsLeft = _cdMinutes * 60; });
  }

  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _fmtD(Duration d) {
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours.toString().padLeft(2, '0')}:$m:$s';
    return '$m:$s.$ms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Timer', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
              ]),
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
        radius: 16,
        child: Row(
          children: TimerTab.values.map((tab) {
            final selected = _tab == tab;
            final label = tab == TimerTab.pomodoro ? 'Pomodoro' : tab == TimerTab.stopwatch ? 'Stopwatch' : 'Countdown';
            final icon = tab == TimerTab.pomodoro ? Icons.self_improvement_rounded : tab == TimerTab.stopwatch ? Icons.speed_rounded : Icons.hourglass_bottom_rounded;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected ? const LinearGradient(colors: [kPurple, Color(0xFF9333EA)]) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: selected ? Colors.white : Colors.white38, size: 16),
                    const SizedBox(height: 3),
                    Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : Colors.white38, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, fontSize: 11)),
                  ]),
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
      case TimerTab.pomodoro: return _pomoContent();
      case TimerTab.stopwatch: return _swContent();
      case TimerTab.countdown: return _cdContent();
    }
  }

  Widget _pomoContent() {
    final total = _pomoBreak ? _breakDuration : _pomoDuration;
    final progress = _pomoSecondsLeft / total;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      child: Column(children: [
        GlassCard(
          child: Column(children: [
            GlassBadge(_pomoBreak ? '☕  Break Time' : '🎯  Focus Session', color: _pomoBreak ? const Color(0xFF0891B2) : kPurple),
            const SizedBox(height: 28),
            SizedBox(
              width: 220, height: 220,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(painter: _RingPainter(progress, _pomoBreak ? const Color(0xFF0891B2) : kPurple), size: const Size(220, 220)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_fmt(_pomoSecondsLeft), style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w200, letterSpacing: 3)),
                  Text(_pomoBreak ? 'rest' : 'focus', style: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 2)),
                ]),
              ]),
            ),
            const SizedBox(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(Icons.refresh_rounded, _resetPomo, size: 52),
              const SizedBox(width: 20),
              _btn(_pomoRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, _togglePomo, size: 68, filled: true),
            ]),
            const SizedBox(height: 20),
            if (_pomoRounds > 0)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                ...List.generate(math.min(_pomoRounds, 4), (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(Icons.circle, color: kPurpleLight, size: 8),
                )),
                if (_pomoRounds > 4) Text('  +${_pomoRounds - 4}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
          ]),
        ),
      ]),
    );
  }

  Widget _swContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        GlassCard(
          child: Column(children: [
            Text(
              _fmtD(_swElapsed),
              style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w200, letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(Icons.flag_rounded, _lapSw, size: 52),
              const SizedBox(width: 20),
              _btn(_stopwatch.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, _toggleSw, size: 68, filled: true),
              const SizedBox(width: 20),
              _btn(Icons.stop_rounded, _resetSw, size: 52),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: _laps.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: kPurpleLight, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text('Lap ${_laps.length - i}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ]),
                  Text(_fmtD(_laps[i]), style: const TextStyle(color: Colors.white, fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _cdContent() {
    final progress = _cdMinutes > 0 ? _cdSecondsLeft / (_cdMinutes * 60) : 1.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      child: GlassCard(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!_cdRunning && _cdSecondsLeft == _cdMinutes * 60) ...[
            const Text('Set duration', style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              GestureDetector(
                onTap: () => setState(() { if (_cdMinutes > 1) { _cdMinutes--; _cdSecondsLeft = _cdMinutes * 60; } }),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.remove_rounded, color: Colors.white54),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('$_cdMinutes min', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300)),
              ),
              GestureDetector(
                onTap: () => setState(() { _cdMinutes++; _cdSecondsLeft = _cdMinutes * 60; }),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_rounded, color: Colors.white54),
                ),
              ),
            ]),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: 200, height: 200,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(painter: _RingPainter(progress, kPurple), size: const Size(200, 200)),
              Text(_fmt(_cdSecondsLeft), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w200, letterSpacing: 3)),
            ]),
          ),
          const SizedBox(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _btn(Icons.refresh_rounded, _resetCd, size: 52),
            const SizedBox(width: 20),
            _btn(_cdRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, _toggleCd, size: 68, filled: true),
          ]),
        ]),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, {required double size, bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled ? const LinearGradient(colors: [kPurple, Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: filled ? null : Colors.white.withAlpha(12),
          border: Border.all(color: filled ? kPurple : Colors.white.withAlpha(20)),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.42),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = cx - 10;
    final stroke = 8.0;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [color, color.withAlpha(180)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}
