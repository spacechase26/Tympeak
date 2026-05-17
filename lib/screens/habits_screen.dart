import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _uuid = const Uuid();
  final _controller = TextEditingController();

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _getStreak(Map data) {
    final logs = List<String>.from(data['logs'] ?? []);
    if (logs.isEmpty) return 0;
    int streak = 0;
    DateTime day = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (logs.contains(key)) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        if (i == 0) { day = day.subtract(const Duration(days: 1)); continue; }
        break;
      }
    }
    return streak;
  }

  void _addHabit(String name) {
    if (name.trim().isEmpty) return;
    Storage.habits.put(_uuid.v4(), {
      'name': name.trim(),
      'logs': <String>[],
      'emoji': '⭐',
      'createdAt': DateTime.now().toIso8601String(),
    });
    _controller.clear();
    Navigator.pop(context);
  }

  void _toggleToday(String key, Map data) {
    final logs = List<String>.from(data['logs'] ?? []);
    final today = _todayKey();
    if (logs.contains(today)) { logs.remove(today); } else { logs.add(today); }
    Storage.habits.put(key, {...data, 'logs': logs});
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassCard(
          radius: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Habit', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'e.g. Exercise, Read, Meditate…',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kPurple),
                  ),
                ),
                onSubmitted: _addHabit,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _addHabit(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Add Habit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0891B2), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.repeat_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Habits', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
                  ]),
                  GestureDetector(
                    onTap: _showAddSheet,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.add_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Storage.habits.listenable(),
                builder: (_, box, __) {
                  final keys = box.keys.toList();
                  if (keys.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(color: kPurple.withAlpha(20), shape: BoxShape.circle),
                          child: const Icon(Icons.repeat_rounded, color: kPurpleLight, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text('No habits yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        const Text('Tap + to build your first habit', style: TextStyle(color: Colors.white38, fontSize: 13)),
                      ]),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    itemCount: keys.length,
                    itemBuilder: (_, i) {
                      final key = keys[i];
                      final data = Map<String, dynamic>.from(box.get(key));
                      final logs = List<String>.from(data['logs'] ?? []);
                      final doneToday = logs.contains(_todayKey());
                      final streak = _getStreak(data);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Dismissible(
                          key: Key(key),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(color: Colors.red.withAlpha(40), borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          ),
                          onDismissed: (_) => Storage.habits.delete(key),
                          child: GlassCard(
                            gradient: doneToday
                                ? LinearGradient(colors: [kPurple.withAlpha(50), Colors.white.withAlpha(6)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                : null,
                            child: Column(
                              children: [
                                Row(children: [
                                  GestureDetector(
                                    onTap: () => _toggleToday(key, data),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: 48, height: 48,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: doneToday
                                            ? const LinearGradient(colors: [kPurple, Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                                            : null,
                                        color: doneToday ? null : Colors.white.withAlpha(10),
                                        border: Border.all(color: doneToday ? kPurple : Colors.white24, width: 1.5),
                                      ),
                                      child: Center(
                                        child: doneToday
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                            : const Icon(Icons.circle_outlined, color: Colors.white38, size: 22),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(data['name'] as String, style: TextStyle(color: doneToday ? Colors.white : Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Row(children: [
                                        if (streak > 0) ...[
                                          const Text('🔥', style: TextStyle(fontSize: 12)),
                                          const SizedBox(width: 3),
                                          Text('$streak day streak', style: const TextStyle(color: kPurpleLight, fontSize: 12, fontWeight: FontWeight.w500)),
                                          const SizedBox(width: 10),
                                        ],
                                        Text('${logs.length} total', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                      ]),
                                    ]),
                                  ),
                                  if (doneToday)
                                    const GlassBadge('Done ✓', color: kPurple),
                                ]),
                                const SizedBox(height: 14),
                                _weekRow(logs),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekRow(List<String> logs) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    return Row(
      children: List.generate(7, (i) {
        final offset = i - (now.weekday - 1);
        final day = now.add(Duration(days: offset));
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final done = logs.contains(key);
        final isToday = offset == 0;
        final isFuture = offset > 0;
        return Expanded(
          child: Column(children: [
            Text(days[i], style: TextStyle(color: isToday ? kPurpleLight : Colors.white30, fontSize: 10, fontWeight: isToday ? FontWeight.w700 : FontWeight.normal)),
            const SizedBox(height: 5),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? const LinearGradient(colors: [kPurple, Color(0xFF9333EA)]) : null,
                color: done ? null : isFuture ? Colors.transparent : Colors.white.withAlpha(8),
                border: isToday ? Border.all(color: kPurpleLight, width: 1.5) : null,
              ),
              child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
          ]),
        );
      }),
    );
  }
}
