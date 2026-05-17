import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/storage.dart';
import '../data/habit_timer.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_padding.dart';
import 'habit_detail_screen.dart';

// ── Palette & emojis ────────────────────────────────────────────────────────
const _kColors = [
  Color(0xFF7C3AED), Color(0xFF0891B2), Color(0xFF16A34A),
  Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFFCA8A04),
];
const _kEmojis = [
  '💪','📚','🧘','💧','🏃','🥗','😴','✍️','🎯','🚭',
  '💊','🧹','🎵','💻','🌅','🙏','🦷','💰','🎨','🐕',
];

// ── Habit helper ─────────────────────────────────────────────────────────────
class Habit {
  final String key;
  final Map raw;
  Habit(this.key, this.raw);

  String get name     => raw['name'] ?? '';
  String get emoji    => raw['emoji'] ?? '⭐';
  Color  get color    => Color((raw['color'] ?? 0xFF7C3AED) as int);
  String get type     => raw['type'] ?? 'yes_no';
  int    get target   => (raw['target'] ?? 1) as int;
  String get schedule => raw['schedule'] ?? 'daily';
  List<int> get customDays => List<int>.from(raw['customDays'] ?? [1,2,3,4,5,6,7]);

  Map<String, int> get logs {
    final r = raw['logs'];
    if (r is List)  return { for (final d in r) d.toString(): 1 };
    if (r is Map)   return r.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    return {};
  }

  String _dk(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  bool isDueOn(DateTime d) {
    final wd = d.weekday;
    switch (schedule) {
      case 'weekdays': return wd <= 5;
      case 'weekends': return wd >= 6;
      case 'custom':   return customDays.contains(wd);
      default:         return true;
    }
  }
  bool get isDueToday => isDueOn(DateTime.now());

  int  valueFor(DateTime d)   => logs[_dk(d)] ?? 0;
  bool doneFor(DateTime d)    => valueFor(d) >= target;
  bool get doneToday          => doneFor(DateTime.now());

  int get streak {
    int s = 0;
    var day = DateTime.now();
    if (!doneToday && isDueToday) day = day.subtract(const Duration(days: 1));
    bool usedGrace = false;
    for (int i = 0; i < 365; i++) {
      if (!isDueOn(day)) { day = day.subtract(const Duration(days: 1)); continue; }
      if (doneFor(day)) {
        s++;
        usedGrace = false;
        day = day.subtract(const Duration(days: 1));
      } else if (!usedGrace) {
        usedGrace = true;
        day = day.subtract(const Duration(days: 1));
      } else { break; }
    }
    return s;
  }

  double rate30() {
    int due = 0, done = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      if (isDueOn(d)) { due++; if (doneFor(d)) done++; }
    }
    return due > 0 ? done / due : 0;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final ConfettiController _confetti;
  bool _initialized = false;
  int  _prevDone    = 0;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  List<Habit> _habits(Box box) =>
      box.keys.map((k) => Habit(k, Map.from(box.get(k)))).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          ValueListenableBuilder(
            valueListenable: Storage.habits.listenable(),
            builder: (ctx, box, _) {
              final habits = _habits(box);
              final due    = habits.where((h) => h.isDueToday).toList();
              final rest   = habits.where((h) => !h.isDueToday).toList();
              final done   = due.where((h) => h.doneToday).length;

              // Fire confetti only when the last habit flips to done (not on first load)
              if (!_initialized) {
                _prevDone    = done;
                _initialized = true;
              } else if (due.isNotEmpty && done == due.length && done > _prevDone) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _confetti.play();
                });
              }
              _prevDone = done;

              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Header(done: done, total: due.length, onAdd: () => _showAddSheet(ctx)),
                Expanded(
                  child: habits.isEmpty
                      ? _Empty(onAdd: () => _showAddSheet(ctx))
                      : ListView(
                          padding: EdgeInsets.fromLTRB(20, 0, 20, navBottomPadding(ctx)),
                          children: [
                            if (due.isNotEmpty) ...[
                              _label('Today'),
                              ...due.map((h) => _HabitCard(habit: h, onTap: () => _openDetail(ctx, h))),
                            ],
                            if (rest.isNotEmpty) ...[
                              _label('Rest days'),
                              ...rest.map((h) => _HabitCard(habit: h, dimmed: true, onTap: () => _openDetail(ctx, h))),
                            ],
                          ],
                        ),
                ),
              ]);
            },
          ),
          // Confetti burst at top-center
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                kPurple, Color(0xFF0891B2), Color(0xFF16A34A),
                Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFFCA8A04),
                Colors.white,
              ],
              numberOfParticles: 40,
              gravity: 0.15,
              emissionFrequency: 0.05,
              maxBlastForce: 22,
              minBlastForce: 8,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
    child: Text(t.toUpperCase(), style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  void _openDetail(BuildContext ctx, Habit h) {
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => HabitDetailScreen(habitKey: h.key)));
  }

  void _showAddSheet(BuildContext ctx, {String? editKey, Map? existingData}) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddHabitSheet(editKey: editKey, existing: existingData),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int done, total;
  final VoidCallback onAdd;
  const _Header({required this.done, required this.total, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0891B2), kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.repeat_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Habits', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
          ]),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ]),
        if (total > 0) ...[
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              SizedBox(
                width: 40, height: 40,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: pct, strokeWidth: 4,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(pct == 1 ? const Color(0xFF16A34A) : kPurple),
                  ),
                  Text('${(pct * 100).round()}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  pct == 1 ? '🎉 All done today!' : '$done of $total habits done',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  pct == 1 ? 'Keep the streak alive!' : '${total - done} remaining',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ])),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ── Shared done circle — consistent across all habit types ────────────────────
class _DoneCircle extends StatelessWidget {
  final Color color;
  const _DoneCircle({required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, color.withAlpha(180)]),
        border: Border.all(color: color, width: 1.5),
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
    );
  }
}

// ── Habit Card ────────────────────────────────────────────────────────────────
class _HabitCard extends StatelessWidget {
  final Habit habit;
  final bool dimmed;
  final VoidCallback onTap;
  const _HabitCard({required this.habit, this.dimmed = false, required this.onTap});

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  void _log(BuildContext ctx, int delta) {
    final box  = Storage.habits;
    final data = Map<String, dynamic>.from(box.get(habit.key));
    final logs = habit.logs;
    final cur  = logs[_todayKey] ?? 0;
    final next = (cur + delta).clamp(0, habit.target);
    logs[_todayKey] = next;
    data['logs'] = logs;
    box.put(habit.key, data);
    HapticFeedback.lightImpact();
  }

  void _undoToday(BuildContext ctx) {
    final box  = Storage.habits;
    final data = Map<String, dynamic>.from(box.get(habit.key));
    final logs = habit.logs;
    if (habit.type == 'count') {
      logs[_todayKey] = habit.target - 1;
    } else {
      logs.remove(_todayKey);
      if (habit.type == 'time_min') {
        HabitTimerManager.instance.reset(habit.key, habit.target * 60);
      }
    }
    data['logs'] = logs;
    box.put(habit.key, data);
    HapticFeedback.lightImpact();
  }

  void _delete(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete habit?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Delete "${habit.name}"? This will erase all its history.', style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            onPressed: () { Storage.habits.delete(habit.key); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withAlpha(180), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done    = habit.doneToday;
    final streak  = habit.streak;
    final rate    = habit.rate30();
    final opacity = dimmed ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onLongPress: () => _showOptions(context),
          child: GlassCard(
            gradient: done
                ? LinearGradient(colors: [habit.color.withAlpha(45), Colors.white.withAlpha(6)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: habit.color.withAlpha(done ? 220 : 40),
                ),
                child: Center(child: Text(habit.emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(habit.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(children: [
                  if (streak > 0) ...[
                    Text('🔥 $streak', style: TextStyle(color: habit.color, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                  ],
                  Text(_scheduleLabel(), style: const TextStyle(color: Colors.white30, fontSize: 11)),
                  if (rate > 0) ...[
                    const SizedBox(width: 8),
                    Text('${(rate * 100).round()}%', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                  ],
                ]),
              ])),
              const SizedBox(width: 8),
              // Logging control — type-aware, consistent done circle
              if (habit.type == 'yes_no')
                _YesNoControl(habit: habit, onLog: (d) => _log(context, d))
              else if (habit.type == 'count')
                _CountControl(habit: habit, onLog: (d) => _log(context, d))
              else
                _TimerControl(habit: habit, onLog: (d) => _log(context, d)),
            ]),
          ),
        ),
      ),
    );
  }

  String _scheduleLabel() {
    switch (habit.schedule) {
      case 'weekdays': return 'Mon–Fri';
      case 'weekends': return 'Sat–Sun';
      case 'custom':
        const names = ['','M','T','W','T','F','S','S'];
        return habit.customDays.map((d) => names[d]).join(' ');
      default: return 'Daily';
    }
  }

  void _showOptions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassCard(
        radius: 28,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('${habit.emoji} ${habit.name}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          if (habit.doneToday)
            _option(ctx, Icons.undo_rounded, 'Undo Today', Colors.orange, () { Navigator.pop(ctx); _undoToday(ctx); }),
          _option(ctx, Icons.bar_chart_rounded, 'View Stats', kPurple, () {
            Navigator.pop(ctx);
            Navigator.push(ctx, MaterialPageRoute(builder: (_) => HabitDetailScreen(habitKey: habit.key)));
          }),
          _option(ctx, Icons.edit_rounded, 'Edit Habit', Colors.white54, () {
            Navigator.pop(ctx);
            showModalBottomSheet(
              context: ctx,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _AddHabitSheet(editKey: habit.key, existing: habit.raw),
            );
          }),
          _option(ctx, Icons.delete_outline_rounded, 'Delete', Colors.red, () { Navigator.pop(ctx); _delete(ctx); }),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _option(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(color: color == Colors.white54 ? Colors.white : color, fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Log Control — Yes/No ──────────────────────────────────────────────────────
class _YesNoControl extends StatelessWidget {
  final Habit habit;
  final void Function(int) onLog;
  const _YesNoControl({required this.habit, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final done = habit.doneToday;
    if (done) return _DoneCircle(color: habit.color);
    return GestureDetector(
      onTap: () => onLog(habit.target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(12),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: const Icon(Icons.circle_outlined, color: Colors.white30, size: 22),
      ),
    );
  }
}

// ── Log Control — Count ───────────────────────────────────────────────────────
class _CountControl extends StatelessWidget {
  final Habit habit;
  final void Function(int) onLog;
  const _CountControl({required this.habit, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final cur  = habit.valueFor(DateTime.now());
    final done = habit.doneToday;
    if (done) return _DoneCircle(color: habit.color);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _btn(Icons.remove_rounded, () => onLog(-1), habit.color, outline: true),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$cur',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text('/${habit.target}',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      ),
      _btn(Icons.add_rounded, () => onLog(1), habit.color),
    ]);
  }

  Widget _btn(IconData icon, VoidCallback onTap, Color color, {bool outline = false}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : color.withAlpha(220),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(outline ? 80 : 220)),
        ),
        child: Icon(icon, color: outline ? color : Colors.white, size: 18),
      ),
    );
}

// ── Log Control — Timer ───────────────────────────────────────────────────────
class _TimerControl extends StatefulWidget {
  final Habit habit;
  final void Function(int) onLog;
  const _TimerControl({required this.habit, required this.onLog});

  @override
  State<_TimerControl> createState() => _TimerControlState();
}

class _TimerControlState extends State<_TimerControl> {
  final _mgr = HabitTimerManager.instance;

  int get _defaultSecs => widget.habit.target * 60;

  void _start() {
    _mgr.start(widget.habit.key, _defaultSecs, () {
      if (mounted) setState(() {});
      widget.onLog(widget.habit.target);
      HapticFeedback.heavyImpact();
    });
    setState(() {});
  }

  void _pause() { _mgr.pause(widget.habit.key); setState(() {}); }

  void _reset(int secs) { _mgr.reset(widget.habit.key, secs); setState(() {}); }

  @override
  Widget build(BuildContext context) {
    if (widget.habit.doneToday) return _DoneCircle(color: widget.habit.color);

    return ValueListenableBuilder(
      valueListenable: _mgr.notifier(widget.habit.key, _defaultSecs),
      builder: (ctx, state, _) {
        final secs    = state.seconds;
        final running = state.running;
        final total   = _defaultSecs;
        final pct     = total > 0 ? 1 - (secs / total) : 0.0;
        final mm      = (secs ~/ 60).toString().padLeft(2, '0');
        final ss      = (secs % 60).toString().padLeft(2, '0');

        return SizedBox(
          width: 100,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('$mm:$ss',
              style: TextStyle(
                color: running ? widget.habit.color : Colors.white70,
                fontSize: 18, fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct, minHeight: 3,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(widget.habit.color),
              ),
            ),
            const SizedBox(height: 6),
            // Reset only shown when running; pause larger than reset
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (running) ...[
                _ctl(Icons.refresh_rounded, () => _reset(total), small: true),
                const SizedBox(width: 6),
              ],
              _ctl(
                running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                running ? _pause : _start,
                filled: true,
                large: running,
                color: widget.habit.color,
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _ctl(IconData icon, VoidCallback onTap, {bool filled = false, bool small = false, bool large = false, Color? color}) {
    final sz = small ? 26.0 : (large ? 36.0 : 32.0);
    final c  = color ?? kPurple;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          color: filled ? c : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
          border: filled ? null : Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Icon(icon, color: Colors.white, size: sz * 0.52),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0891B2), kPurple]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.repeat_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 20),
          const Text('Build your first habit', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Small consistent actions compound into big results.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a Habit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPurple, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              elevation: 0,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Add / Edit Sheet ──────────────────────────────────────────────────────────
class _AddHabitSheet extends StatefulWidget {
  final String? editKey;
  final dynamic existing;
  const _AddHabitSheet({this.editKey, this.existing});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _name = TextEditingController();
  final _uuid = const Uuid();
  String _emoji    = '⭐';
  Color  _color    = _kColors[0];
  String _type     = 'yes_no';
  int    _target   = 1;
  String _schedule = 'daily';
  List<int> _customDays = [1, 2, 3, 4, 5, 6, 7];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final d = widget.existing;
      _name.text  = d['name'] ?? '';
      _emoji      = d['emoji'] ?? '⭐';
      _color      = Color((d['color'] ?? 0xFF7C3AED) as int);
      _type       = d['type'] ?? 'yes_no';
      _target     = (d['target'] ?? 1) as int;
      _schedule   = d['schedule'] ?? 'daily';
      _customDays = List<int>.from(d['customDays'] ?? [1,2,3,4,5,6,7]);
    }
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    final Map<String, dynamic> data = {
      'name':       _name.text.trim(),
      'emoji':      _emoji,
      'color':      _color.toARGB32(),
      'type':       _type,
      'target':     _target,
      'schedule':   _schedule,
      'customDays': _customDays,
      'logs':       widget.existing != null
          ? Habit('', widget.existing!).logs
          : <String, int>{},
      'createdAt':  widget.existing?['createdAt'] ?? DateTime.now().toIso8601String(),
    };
    if (widget.editKey != null) {
      Storage.habits.put(widget.editKey!, data);
    } else {
      Storage.habits.put(_uuid.v4(), data);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassCard(
        radius: 28,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.editKey != null ? 'Edit Habit' : 'New Habit',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),

            Row(children: [
              GestureDetector(
                onTap: _pickEmoji,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: _color.withAlpha(40), borderRadius: BorderRadius.circular(14), border: Border.all(color: _color.withAlpha(80))),
                  child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 26))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Habit name…',
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true, fillColor: Colors.white.withAlpha(10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _color)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            _sectionLabel('Color'),
            const SizedBox(height: 8),
            Row(children: _kColors.map((c) => GestureDetector(
              onTap: () => setState(() => _color = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 32, height: 32, margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: c,
                  border: _color == c ? Border.all(color: Colors.white, width: 2.5) : null,
                  boxShadow: _color == c ? [BoxShadow(color: c.withAlpha(120), blurRadius: 8)] : null,
                ),
              ),
            )).toList()),
            const SizedBox(height: 16),

            _sectionLabel('Type'),
            const SizedBox(height: 8),
            _TypeSelector(value: _type, color: _color, onChange: (t) => setState(() { _type = t; if (t == 'yes_no') _target = 1; })),
            if (_type != 'yes_no') ...[
              const SizedBox(height: 12),
              _TargetRow(type: _type, target: _target, color: _color, onChange: (v) => setState(() => _target = v)),
            ],
            const SizedBox(height: 16),

            _sectionLabel('Schedule'),
            const SizedBox(height: 8),
            _ScheduleSelector(
              value: _schedule, customDays: _customDays, color: _color,
              onSchedule: (s) => setState(() => _schedule = s),
              onDays: (d) => setState(() => _customDays = d),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _color, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(widget.editKey != null ? 'Save Changes' : 'Add Habit',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
          ]),
        ),
      ),
    );
  }

  void _pickEmoji() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassCard(
        radius: 24,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Pick an emoji', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _kEmojis.map((e) => GestureDetector(
              onTap: () { setState(() => _emoji = e); Navigator.pop(context); },
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
              ),
            )).toList(),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

// ── Type Selector ─────────────────────────────────────────────────────────────
class _TypeSelector extends StatelessWidget {
  final String value;
  final Color color;
  final void Function(String) onChange;
  const _TypeSelector({required this.value, required this.color, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final types = [
      ('yes_no',   '✓  Yes / No',    'Done or not done'),
      ('count',    '🔢  Count',       'Track a number'),
      ('time_min', '⏱  Time (min)',  'Track minutes'),
    ];
    return Column(children: types.map((t) {
      final sel = value == t.$1;
      return GestureDetector(
        onTap: () => onChange(t.$1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color.withAlpha(40) : Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? color : Colors.white12),
          ),
          child: Row(children: [
            Text(t.$2, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontWeight: sel ? FontWeight.w600 : FontWeight.normal, fontSize: 14)),
            const Spacer(),
            Text(t.$3, style: const TextStyle(color: Colors.white30, fontSize: 12)),
            if (sel) ...[const SizedBox(width: 8), Icon(Icons.check_circle_rounded, color: color, size: 16)],
          ]),
        ),
      );
    }).toList());
  }
}

// ── Target Row — +/- for count, keyboard input for time_min ───────────────────
class _TargetRow extends StatefulWidget {
  final String type;
  final int target;
  final Color color;
  final void Function(int) onChange;
  const _TargetRow({required this.type, required this.target, required this.color, required this.onChange});

  @override
  State<_TargetRow> createState() => _TargetRowState();
}

class _TargetRowState extends State<_TargetRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.target}');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.type == 'time_min') {
      return Row(children: [
        const Text('Target (minutes)', style: TextStyle(color: Colors.white54, fontSize: 13)),
        const Spacer(),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(color: widget.color, fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              filled: true,
              fillColor: widget.color.withAlpha(20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.color.withAlpha(80))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.color.withAlpha(80))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.color)),
              suffixText: 'min',
              suffixStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
            onChanged: (v) {
              final val = int.tryParse(v);
              if (val != null && val > 0) widget.onChange(val);
            },
          ),
        ),
      ]);
    }

    // Count type: +/- stepper
    return Row(children: [
      const Text('Target (count)', style: TextStyle(color: Colors.white54, fontSize: 13)),
      const Spacer(),
      GestureDetector(
        onTap: () { if (widget.target > 1) widget.onChange(widget.target - 1); },
        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.remove_rounded, color: Colors.white54, size: 16)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('${widget.target}', style: TextStyle(color: widget.color, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      GestureDetector(
        onTap: () => widget.onChange(widget.target + 1),
        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: widget.color.withAlpha(40), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.add_rounded, color: widget.color, size: 16)),
      ),
    ]);
  }
}

// ── Schedule Selector ─────────────────────────────────────────────────────────
class _ScheduleSelector extends StatelessWidget {
  final String value;
  final List<int> customDays;
  final Color color;
  final void Function(String) onSchedule;
  final void Function(List<int>) onDays;
  const _ScheduleSelector({required this.value, required this.customDays, required this.color, required this.onSchedule, required this.onDays});

  @override
  Widget build(BuildContext context) {
    final opts = [('daily','Daily'),('weekdays','Weekdays'),('weekends','Weekends'),('custom','Custom')];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: opts.map((o) {
        final sel = value == o.$1;
        return Expanded(child: GestureDetector(
          onTap: () => onSchedule(o.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? color : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? color : Colors.white12),
            ),
            child: Text(o.$2, textAlign: TextAlign.center,
              style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
          ),
        ));
      }).toList()),
      if (value == 'custom') ...[
        const SizedBox(height: 10),
        _DayPicker(selected: customDays, color: color, onChange: onDays),
      ],
    ]);
  }
}

class _DayPicker extends StatelessWidget {
  final List<int> selected;
  final Color color;
  final void Function(List<int>) onChange;
  const _DayPicker({required this.selected, required this.color, required this.onChange});

  @override
  Widget build(BuildContext context) {
    const days = ['M','T','W','T','F','S','S'];
    return Row(children: List.generate(7, (i) {
      final day = i + 1;
      final on  = selected.contains(day);
      return Expanded(child: GestureDetector(
        onTap: () {
          final next = List<int>.from(selected);
          if (on) { if (next.length > 1) next.remove(day); }
          else { next.add(day); next.sort(); }
          onChange(next);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(right: 4),
          height: 36,
          decoration: BoxDecoration(
            color: on ? color : Colors.white.withAlpha(8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? color : Colors.white12),
          ),
          child: Center(child: Text(days[i], style: TextStyle(color: on ? Colors.white : Colors.white38, fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.normal))),
        ),
      ));
    }));
  }
}
