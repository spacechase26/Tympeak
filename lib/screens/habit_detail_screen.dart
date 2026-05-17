import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import 'habits_screen.dart';

class HabitDetailScreen extends StatelessWidget {
  final String habitKey;
  const HabitDetailScreen({super.key, required this.habitKey});

  @override
  Widget build(BuildContext context) {
    final raw  = Storage.habits.get(habitKey);
    if (raw == null) { Navigator.pop(context); return const SizedBox(); }
    final h = Habit(habitKey, Map.from(raw));

    final streak    = h.streak;
    final rate30    = h.rate30();
    final totalDone = h.logs.values.where((v) => v >= h.target).length;
    final bestStreak = _bestStreak(h);

    return Scaffold(
      backgroundColor: kBgDeep,
      body: Stack(children: [
        // Background glow matching habit color
        Positioned(top: -60, left: -60, child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [h.color.withAlpha(50), Colors.transparent]),
          ),
        )),
        SafeArea(
          child: Column(children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Text(h.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Text(h.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // Stats row
                  Row(children: [
                    _StatCard(label: 'Streak', value: '$streak', sub: streak == 1 ? 'day' : 'days', icon: '🔥', color: h.color),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Best', value: '$bestStreak', sub: 'days', icon: '🏆', color: h.color),
                    const SizedBox(width: 10),
                    _StatCard(label: '30-day', value: '${(rate30 * 100).round()}%', sub: 'rate', icon: '📈', color: h.color),
                    const SizedBox(width: 10),
                    _StatCard(label: 'Total', value: '$totalDone', sub: 'done', icon: '✅', color: h.color),
                  ]),

                  const SizedBox(height: 20),

                  // Heatmap
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Activity', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        Row(children: [
                          _dot(Colors.white.withAlpha(20), 'None'),
                          const SizedBox(width: 8),
                          _dot(h.color.withAlpha(100), 'Partial'),
                          const SizedBox(width: 8),
                          _dot(h.color, 'Done'),
                        ]),
                      ]),
                      const SizedBox(height: 14),
                      _Heatmap(habit: h),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Day-of-week breakdown
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Best Days', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      _DayBreakdown(habit: h),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Recent 4 weeks
                  GlassCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Last 4 Weeks', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      _WeeklyBars(habit: h),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Schedule info
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(width: 36, height: 36, decoration: BoxDecoration(color: h.color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.calendar_today_rounded, color: h.color, size: 18)),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Schedule', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        Text(_scheduleText(h), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                      const Spacer(),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Type', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        Text(_typeText(h), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _dot(Color c, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
  ]);

  int _bestStreak(Habit h) {
    int best = 0, cur = 0;
    final now = DateTime.now();
    for (int i = 365; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      if (!h.isDueOn(d)) continue;
      if (h.doneFor(d)) { cur++; best = math.max(best, cur); }
      else { cur = 0; }
    }
    return best;
  }

  String _scheduleText(Habit h) {
    switch (h.schedule) {
      case 'weekdays': return 'Monday – Friday';
      case 'weekends': return 'Saturday – Sunday';
      case 'custom':
        const n = ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
        return h.customDays.map((d) => n[d]).join(', ');
      default: return 'Every day';
    }
  }

  String _typeText(Habit h) {
    switch (h.type) {
      case 'count':    return 'Count (×${h.target})';
      case 'time_min': return 'Time (${h.target} min)';
      default:         return 'Yes / No';
    }
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, sub, icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.sub, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── GitHub-style Heatmap ──────────────────────────────────────────────────────
class _Heatmap extends StatelessWidget {
  final Habit habit;
  const _Heatmap({required this.habit});

  @override
  Widget build(BuildContext context) {
    // Show 15 weeks (105 days), newest on right
    const weeks = 15;
    final now = DateTime.now();
    // Start from the Monday of (weeks) weeks ago
    final startOffset = now.weekday - 1 + (weeks - 1) * 7;
    final start = now.subtract(Duration(days: startOffset));

    final monthLabels = <int, String>{};
    for (int w = 0; w < weeks; w++) {
      final d = start.add(Duration(days: w * 7));
      if (d.day <= 7) monthLabels[w] = _monthAbbr(d.month);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Month labels
      SizedBox(
        height: 14,
        child: Row(children: List.generate(weeks, (w) {
          final label = monthLabels[w];
          return Expanded(child: label != null
              ? Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9))
              : const SizedBox());
        })),
      ),
      const SizedBox(height: 4),
      Row(children: List.generate(weeks, (w) {
        return Expanded(child: Column(children: List.generate(7, (dow) {
          final d = start.add(Duration(days: w * 7 + dow));
          final isFuture = d.isAfter(now);
          final isDue = habit.isDueOn(d);
          final val = habit.valueFor(d);
          final done = habit.doneFor(d);

          Color cellColor;
          if (isFuture || !isDue) {
            cellColor = Colors.white.withAlpha(isFuture ? 0 : 12);
          } else if (done) {
            cellColor = habit.color;
          } else if (val > 0) {
            cellColor = habit.color.withAlpha(120);
          } else {
            cellColor = Colors.white.withAlpha(18);
          }

          return Container(
            margin: const EdgeInsets.all(1.5),
            width: double.infinity,
            height: 10,
            decoration: BoxDecoration(color: cellColor, borderRadius: BorderRadius.circular(2)),
          );
        })));
      })),
      const SizedBox(height: 4),
      // Day labels
      Row(children: ['M','','W','','F','','S'].map((l) =>
        Expanded(child: Center(child: Text(l, style: const TextStyle(color: Colors.white30, fontSize: 8))))).toList()),
    ]);
  }

  String _monthAbbr(int m) => ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
}

// ── Day-of-week breakdown ─────────────────────────────────────────────────────
class _DayBreakdown extends StatelessWidget {
  final Habit habit;
  const _DayBreakdown({required this.habit});

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final counts = List.filled(7, 0);
    final totals = List.filled(7, 0);
    final now = DateTime.now();
    for (int i = 0; i < 90; i++) {
      final d = now.subtract(Duration(days: i));
      final wd = d.weekday - 1; // 0=Mon
      if (habit.isDueOn(d)) {
        totals[wd]++;
        if (habit.doneFor(d)) counts[wd]++;
      }
    }
    final maxRate = List.generate(7, (i) => totals[i] > 0 ? counts[i] / totals[i] : 0.0).fold(0.0, math.max);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final rate = totals[i] > 0 ? counts[i] / totals[i] : 0.0;
        final relH = maxRate > 0 ? rate / maxRate : 0.0;
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(children: [
            Text('${(rate * 100).round()}%', style: TextStyle(color: rate > 0.8 ? habit.color : Colors.white30, fontSize: 9, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              height: (relH * 50).clamp(4.0, 50.0),
              decoration: BoxDecoration(
                color: rate > 0.8 ? habit.color : habit.color.withAlpha(60),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(dayNames[i], style: const TextStyle(color: Colors.white38, fontSize: 9)),
          ]),
        ));
      }),
    );
  }
}

// ── Weekly bars (last 4 weeks) ────────────────────────────────────────────────
class _WeeklyBars extends StatelessWidget {
  final Habit habit;
  const _WeeklyBars({required this.habit});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weeks = List.generate(4, (w) {
      int due = 0, done = 0;
      for (int d = 0; d < 7; d++) {
        final day = now.subtract(Duration(days: w * 7 + d));
        if (habit.isDueOn(day)) { due++; if (habit.doneFor(day)) done++; }
      }
      return (due: due, done: done);
    }).reversed.toList();

    final maxDue = weeks.fold(1, (m, w) => math.max(m, w.due));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final w = weeks[i];
        final pct = w.due > 0 ? w.done / w.due : 0.0;
        final relH = w.due / maxDue;
        final label = i == 3 ? 'This\nweek' : '${4 - i}w\nago';
        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(children: [
            Text('${w.done}/${w.due}', style: TextStyle(color: pct > 0.8 ? habit.color : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 60 * relH,
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withAlpha(12),
                  valueColor: AlwaysStoppedAnimation(pct > 0.8 ? habit.color : habit.color.withAlpha(120)),
                  minHeight: math.max(60 * relH, 8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        ));
      }),
    );
  }
}
