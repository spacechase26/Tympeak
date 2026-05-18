import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/keep_alive.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_padding.dart';

enum TimerTab { pomodoro, stopwatch, countdown }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});
  @override State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  TimerTab _tab = TimerTab.pomodoro;

  // Configurable defaults (persisted)
  int _focusMin = 25;
  int _breakMin = 5;
  int _loops    = 4;
  int _cdSec    = 600;

  // Pomodoro runtime
  bool _pomoRunning = false;
  bool _pomoBreak   = false;
  int  _pomoRound   = 1;          // 1-indexed
  int  _pomoSegmentLeft = 0;      // seconds left in current focus/break
  Timer? _pomoUiTimer;

  // Countdown runtime
  bool _cdRunning = false;
  int  _cdSecondsLeft = 0;
  Timer? _cdUiTimer;

  // Stopwatch runtime
  bool _swRunning = false;
  int  _swElapsedMs = 0;     // accumulated total elapsed
  int  _swStartMs   = 0;     // wall-clock millis when (re)started
  Timer? _swUiTimer;
  List<int> _laps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConfig();
    _restoreActive();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pomoUiTimer?.cancel();
    _cdUiTimer?.cancel();
    _swUiTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _restoreActive();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  void _loadConfig() {
    final b = Storage.pomodoro;
    _focusMin = (b.get('cfg_focus_min') as int?) ?? 25;
    _breakMin = (b.get('cfg_break_min') as int?) ?? 5;
    _loops    = (b.get('cfg_loops')     as int?) ?? 4;
    _cdSec    = (b.get('cfg_cd_sec')    as int?) ?? 600;
  }

  void _saveConfig() {
    Storage.pomodoro.put('cfg_focus_min', _focusMin);
    Storage.pomodoro.put('cfg_break_min', _breakMin);
    Storage.pomodoro.put('cfg_loops',     _loops);
    Storage.pomodoro.put('cfg_cd_sec',    _cdSec);
  }

  Map<String, dynamic>? _getActive() {
    final raw = Storage.pomodoro.get('active');
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  void _clearActive() {
    Storage.pomodoro.delete('active');
    TimerKeepAlive.stop();
  }

  // Pomodoro naturally completed (detected by the UI ticker). All
  // notification-firing is the background task handler's job — main isolate
  // just resets UI state and stops the keep-alive service. Background
  // handler may have already fired the completion alert via its own
  // detection; calling stop() is idempotent.
  Future<void> _firePomoCompletion(bool wasRunning) async {
    Storage.pomodoro.delete('active');
    await TimerKeepAlive.stop();

    if (!mounted) return;
    setState(() {
      _pomoRunning = false; _pomoBreak = false; _pomoRound = 1;
      _pomoSegmentLeft = _focusMin * 60;
    });
    if (wasRunning) HapticFeedback.heavyImpact();
  }

  Future<void> _fireCdCompletion(bool wasRunning) async {
    Storage.pomodoro.delete('active');
    await TimerKeepAlive.stop();

    if (!mounted) return;
    setState(() { _cdRunning = false; _cdSecondsLeft = _cdSec; });
    if (wasRunning) HapticFeedback.heavyImpact();
  }

  // On (re)entry, look at stored active state and restore UI.
  void _restoreActive() {
    final a = _getActive();
    _pomoUiTimer?.cancel();
    _cdUiTimer?.cancel();
    _swUiTimer?.cancel();
    if (a == null) {
      setState(() {
        _pomoRunning = false; _pomoRound = 1; _pomoBreak = false;
        _pomoSegmentLeft = _focusMin * 60;
        _cdRunning   = false; _cdSecondsLeft = _cdSec;
        _swRunning   = false; _swElapsedMs = 0; _laps = [];
      });
      return;
    }
    // A timer is active — make sure the background isolate is running so
    // notifications keep firing if the user locks / swipes the app away.
    TimerKeepAlive.start(a);
    switch (a['type'] as String) {
      case 'pomodoro':   _restorePomo(a);   break;
      case 'countdown':  _restoreCd(a);     break;
      case 'stopwatch':  _restoreSw(a);     break;
    }
  }

  void _restorePomo(Map<String, dynamic> a) {
    final startedMs = a['startedMs'] as int;
    final focusSec  = a['focusSec']  as int;
    final breakSec  = a['breakSec']  as int;
    final loops     = a['loops']     as int;
    final nowMs     = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = (nowMs - startedMs) ~/ 1000;

    final prevRound = _pomoRound;
    final prevBreak = _pomoBreak;
    final wasRunning = _pomoRunning;

    int cursor = 0;
    int round  = 1;
    bool inBreak = false;
    int segLen = focusSec;
    while (round <= loops) {
      segLen = inBreak ? breakSec : focusSec;
      if (elapsedSec < cursor + segLen) break;
      cursor += segLen;
      if (!inBreak) {
        if (round == loops) {
          _firePomoCompletion(wasRunning);
          return;
        }
        inBreak = true;
      } else {
        inBreak = false;
        round++;
      }
    }
    final segLeft = segLen - (elapsedSec - cursor);

    // Visual segment transition — haptic only. Background isolate owns the
    // notification side of the transition.
    final transitioned = wasRunning && (prevRound != round || prevBreak != inBreak);
    if (transitioned) HapticFeedback.mediumImpact();

    setState(() {
      _focusMin = focusSec ~/ 60;
      _breakMin = breakSec ~/ 60;
      _loops    = loops;
      _pomoRunning = true;
      _pomoBreak   = inBreak;
      _pomoRound   = round;
      _pomoSegmentLeft = segLeft;
      _tab = TimerTab.pomodoro;
    });
    _startPomoUiTick();
  }

  void _restoreCd(Map<String, dynamic> a) {
    final startedMs = a['startedMs'] as int;
    final totalSec  = a['totalSec']  as int;
    final nowMs     = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = (nowMs - startedMs) ~/ 1000;
    final left = totalSec - elapsedSec;
    if (left <= 0) {
      _fireCdCompletion(_cdRunning);
      return;
    }
    setState(() {
      _cdSec = totalSec;
      _cdSecondsLeft = left;
      _cdRunning = true;
      _tab = TimerTab.countdown;
    });
    _startCdUiTick();
  }

  void _restoreSw(Map<String, dynamic> a) {
    final startedMs = a['startedMs'] as int;
    final priorMs   = (a['priorMs'] as int?) ?? 0;
    final paused    = a['paused']  == true;
    final laps      = List<int>.from(a['laps'] as List? ?? []);
    final nowMs     = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _laps = laps;
      _swElapsedMs = paused ? priorMs : priorMs + (nowMs - startedMs);
      _swStartMs   = startedMs;
      _swRunning   = !paused;
      _tab = TimerTab.stopwatch;
    });
    if (_swRunning) _startSwUiTick();
  }

  // ── Pomodoro control ──────────────────────────────────────────────────────
  void _startPomo() {
    _clearActive();
    final focusSec  = _focusMin * 60;
    final breakSec  = _breakMin * 60;
    final loops     = _loops;
    final startedMs = DateTime.now().millisecondsSinceEpoch;
    _saveConfig();

    final active = <String, dynamic>{
      'type': 'pomodoro',
      'startedMs': startedMs,
      'focusSec': focusSec,
      'breakSec': breakSec,
      'loops':    loops,
    };
    Storage.pomodoro.put('active', active);

    setState(() {
      _pomoRunning = true;
      _pomoBreak   = false;
      _pomoRound   = 1;
      _pomoSegmentLeft = focusSec;
    });
    // Background isolate owns notifications: live chronometer + per-segment
    // alerts + final completion. UI just ticks for the on-screen counter.
    TimerKeepAlive.start(active);
    _startPomoUiTick();
  }

  void _startPomoUiTick() {
    _pomoUiTimer?.cancel();
    _pomoUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final a = _getActive();
      if (a == null || a['type'] != 'pomodoro') {
        _pomoUiTimer?.cancel();
        return;
      }
      _restorePomo(a);
    });
  }

  void _resetPomo() {
    _pomoUiTimer?.cancel();
    _clearActive();
    setState(() {
      _pomoRunning = false; _pomoBreak = false; _pomoRound = 1;
      _pomoSegmentLeft = _focusMin * 60;
    });
  }

  // ── Countdown control ─────────────────────────────────────────────────────
  void _startCd() {
    _clearActive();
    final total     = _cdSec;
    final startedMs = DateTime.now().millisecondsSinceEpoch;
    _saveConfig();

    final active = <String, dynamic>{
      'type': 'countdown',
      'startedMs': startedMs,
      'totalSec':  total,
    };
    Storage.pomodoro.put('active', active);
    setState(() {
      _cdRunning = true;
      _cdSecondsLeft = total;
    });
    TimerKeepAlive.start(active);
    _startCdUiTick();
  }

  void _startCdUiTick() {
    _cdUiTimer?.cancel();
    _cdUiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final a = _getActive();
      if (a == null || a['type'] != 'countdown') {
        _cdUiTimer?.cancel();
        return;
      }
      _restoreCd(a);
    });
  }

  void _resetCd() {
    _cdUiTimer?.cancel();
    _clearActive();
    setState(() { _cdRunning = false; _cdSecondsLeft = _cdSec; });
  }

  void _setCdPreset(int sec) {
    if (_cdRunning) return;
    setState(() { _cdSec = sec; _cdSecondsLeft = sec; });
    _saveConfig();
  }

  // ── Stopwatch control ─────────────────────────────────────────────────────
  void _toggleSw() {
    if (_swRunning) {
      // pause
      _swUiTimer?.cancel();
      final active = <String, dynamic>{
        'type': 'stopwatch',
        'startedMs': _swStartMs,
        'priorMs':   _swElapsedMs,
        'paused':    true,
        'laps':      _laps,
      };
      Storage.pomodoro.put('active', active);
      TimerKeepAlive.update(active);
      setState(() => _swRunning = false);
    } else {
      // start or resume
      final priorMs = _swElapsedMs;
      _swStartMs = DateTime.now().millisecondsSinceEpoch;
      final active = <String, dynamic>{
        'type': 'stopwatch',
        'startedMs': _swStartMs,
        'priorMs':   priorMs,
        'paused':    false,
        'laps':      _laps,
      };
      Storage.pomodoro.put('active', active);
      TimerKeepAlive.start(active);
      setState(() => _swRunning = true);
      _startSwUiTick();
    }
  }

  void _startSwUiTick() {
    _swUiTimer?.cancel();
    _swUiTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final a = _getActive();
      if (a == null || a['type'] != 'stopwatch' || a['paused'] == true) {
        _swUiTimer?.cancel();
        return;
      }
      final priorMs   = (a['priorMs'] as int?) ?? 0;
      final startedMs = a['startedMs'] as int;
      final nowMs     = DateTime.now().millisecondsSinceEpoch;
      setState(() => _swElapsedMs = priorMs + (nowMs - startedMs));
    });
  }

  void _resetSw() {
    _swUiTimer?.cancel();
    _clearActive();
    setState(() { _swRunning = false; _swElapsedMs = 0; _laps = []; });
  }

  void _lapSw() {
    if (!_swRunning) return;
    setState(() => _laps.insert(0, _swElapsedMs));
    final a = _getActive();
    if (a != null) {
      a['laps'] = _laps;
      Storage.pomodoro.put('active', a);
      TimerKeepAlive.update(a);
    }
  }

  // ── Formatting ────────────────────────────────────────────────────────────
  String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _fmtMs(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final cs = (ms % 1000) ~/ 10;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
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
          const SizedBox(height: 20),
          Expanded(child: _tabContent()),
        ]),
      ),
    );
  }

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(4),
        radius: 16,
        child: Row(children: TimerTab.values.map((tab) {
          final selected = _tab == tab;
          final label = tab == TimerTab.pomodoro ? 'Pomodoro' : tab == TimerTab.stopwatch ? 'Stopwatch' : 'Countdown';
          final icon  = tab == TimerTab.pomodoro ? Icons.self_improvement_rounded : tab == TimerTab.stopwatch ? Icons.speed_rounded : Icons.hourglass_bottom_rounded;
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
        }).toList()),
      ),
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case TimerTab.pomodoro:  return _pomoContent();
      case TimerTab.stopwatch: return _swContent();
      case TimerTab.countdown: return _cdContent();
    }
  }

  // ── Pomodoro UI ───────────────────────────────────────────────────────────
  Widget _pomoContent() {
    final total = _pomoBreak ? _breakMin * 60 : _focusMin * 60;
    final progress = total > 0 ? _pomoSegmentLeft / total : 0.0;
    final color = _pomoBreak ? const Color(0xFF0891B2) : kPurple;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, navBottomPadding(context)),
      child: Column(children: [
        GlassCard(
          child: Column(children: [
            GlassBadge(
              _pomoRunning
                ? (_pomoBreak ? '☕  Break · Round $_pomoRound/$_loops' : '🎯  Focus · Round $_pomoRound/$_loops')
                : '🎯  Ready to focus',
              color: color,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 220, height: 220,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(painter: _RingPainter(progress, color), size: const Size(220, 220)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_fmt(_pomoRunning ? _pomoSegmentLeft : _focusMin * 60),
                    style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w200, letterSpacing: 3, fontFeatures: [FontFeature.tabularFigures()])),
                  Text(_pomoRunning ? (_pomoBreak ? 'rest' : 'focus') : 'tap play',
                    style: const TextStyle(color: Colors.white38, fontSize: 13, letterSpacing: 2)),
                ]),
              ]),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(Icons.refresh_rounded, _resetPomo, size: 52),
              const SizedBox(width: 20),
              _btn(_pomoRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                   _pomoRunning ? _resetPomo : _startPomo, size: 68, filled: true),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        if (!_pomoRunning) _pomoConfigCard(),
      ]),
    );
  }

  Widget _pomoConfigCard() {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SESSION', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 14),
        _configRow('Focus',  _focusMin, 1, 120,  'min', (v) => setState(() { _focusMin = v; _pomoSegmentLeft = v * 60; _saveConfig(); })),
        const Divider(color: Colors.white10, height: 22),
        _configRow('Break',  _breakMin, 1, 60,   'min', (v) => setState(() { _breakMin = v; _saveConfig(); })),
        const Divider(color: Colors.white10, height: 22),
        _configRow('Loops',  _loops,    1, 12,   '',    (v) => setState(() { _loops    = v; _saveConfig(); })),
      ]),
    );
  }

  Widget _configRow(String label, int value, int min, int max, String unit, ValueChanged<int> onChange) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
      _stepperBtn(Icons.remove_rounded, () { if (value > min) onChange(value - 1); }),
      SizedBox(width: 64,
        child: GestureDetector(
          onTap: () => _editValueDialog(label, value, min, max, unit, onChange),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(unit.isEmpty ? '$value' : '$value $unit',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
      _stepperBtn(Icons.add_rounded, () { if (value < max) onChange(value + 1); }),
    ]);
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white70, size: 16),
      ),
    );
  }

  Future<void> _editValueDialog(String label, int current, int min, int max, String unit, ValueChanged<int> onChange) async {
    final ctrl = TextEditingController(text: '$current');
    final v = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kPurple)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null) Navigator.pop(context, n.clamp(min, max));
            },
            style: ElevatedButton.styleFrom(backgroundColor: kPurple, foregroundColor: Colors.white, elevation: 0),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (v != null) onChange(v);
  }

  // ── Stopwatch UI ──────────────────────────────────────────────────────────
  Widget _swContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        GlassCard(
          child: Column(children: [
            Text(_fmtMs(_swElapsedMs),
              style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.w200, letterSpacing: 2, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(Icons.flag_rounded, _lapSw, size: 52),
              const SizedBox(width: 20),
              _btn(_swRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, _toggleSw, size: 68, filled: true),
              const SizedBox(width: 20),
              _btn(Icons.stop_rounded, _resetSw, size: 52),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: navBottomPadding(context)),
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
                  Text(_fmtMs(_laps[i]), style: const TextStyle(color: Colors.white, fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Countdown UI ──────────────────────────────────────────────────────────
  static const _kCdPresets = [60, 300, 600, 900, 1500, 2700, 3600];

  Widget _cdContent() {
    final progress = _cdSec > 0 ? _cdSecondsLeft / _cdSec : 1.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, navBottomPadding(context)),
      child: Column(children: [
        GlassCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 200, height: 200,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(painter: _RingPainter(progress, kPurple), size: const Size(200, 200)),
                Text(_fmt(_cdSecondsLeft),
                  style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w200, letterSpacing: 3, fontFeatures: [FontFeature.tabularFigures()])),
              ]),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _btn(Icons.refresh_rounded, _resetCd, size: 52),
              const SizedBox(width: 20),
              _btn(_cdRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                   _cdRunning ? _resetCd : _startCd, size: 68, filled: true),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        if (!_cdRunning) _cdPresetsCard(),
      ]),
    );
  }

  Widget _cdPresetsCard() {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('QUICK START', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final sec in _kCdPresets) _cdPresetChip(sec),
          _cdCustomChip(),
        ]),
        const SizedBox(height: 14),
        const Text('FINE TUNE', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _stepperBtn(Icons.remove_rounded, () { if (_cdSec > 60) _setCdPreset(_cdSec - 60); }),
          const SizedBox(width: 12),
          Text('${_cdSec ~/ 60} min', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w300)),
          const SizedBox(width: 12),
          _stepperBtn(Icons.add_rounded, () => _setCdPreset(_cdSec + 60)),
        ]),
      ]),
    );
  }

  Widget _cdPresetChip(int sec) {
    final selected = _cdSec == sec;
    final label = sec < 60 ? '${sec}s' : sec % 60 == 0 ? '${sec ~/ 60}m' : '${(sec / 60).toStringAsFixed(1)}m';
    return GestureDetector(
      onTap: () => _setCdPreset(sec),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPurple : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kPurple : Colors.white12),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _cdCustomChip() {
    return GestureDetector(
      onTap: () => _editValueDialog('Minutes', _cdSec ~/ 60, 1, 600, 'min', (v) => _setCdPreset(v * 60)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, style: BorderStyle.solid),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.edit_rounded, color: Colors.white54, size: 13),
          SizedBox(width: 5),
          Text('Custom', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  // ── Shared ────────────────────────────────────────────────────────────────
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
    const stroke = 8.0;

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
