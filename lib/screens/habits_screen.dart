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
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (logs.contains(key)) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        if (i == 0) {
          day = day.subtract(const Duration(days: 1));
          continue;
        }
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
      'createdAt': DateTime.now().toIso8601String(),
    });
    _controller.clear();
  }

  void _toggleToday(String key, Map data) {
    final logs = List<String>.from(data['logs'] ?? []);
    final today = _todayKey();
    if (logs.contains(today)) {
      logs.remove(today);
    } else {
      logs.add(today);
    }
    Storage.habits.put(key, {...data, 'logs': logs});
  }

  void _deleteHabit(String key) {
    Storage.habits.delete(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text('Habits', style: Theme.of(context).appBarTheme.titleTextStyle),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'New habit…',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _addHabit,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded, color: kPurpleLight),
                      onPressed: () => _addHabit(_controller.text),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: Storage.habits.listenable(),
                builder: (_, box, __) {
                  final keys = box.keys.toList();
                  if (keys.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.loop_rounded, size: 48, color: Colors.white12),
                          const SizedBox(height: 12),
                          const Text('No habits yet', style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: keys.length,
                    itemBuilder: (_, i) {
                      final key = keys[i];
                      final data = Map<String, dynamic>.from(box.get(key));
                      final logs = List<String>.from(data['logs'] ?? []);
                      final doneToday = logs.contains(_todayKey());
                      final streak = _getStreak(data);
                      final totalDone = logs.length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleToday(key, data),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: doneToday ? kPurple : Colors.transparent,
                                        border: Border.all(
                                          color: doneToday ? kPurple : Colors.white30,
                                          width: 2,
                                        ),
                                      ),
                                      child: doneToday
                                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      data['name'] as String,
                                      style: TextStyle(
                                        color: doneToday ? Colors.white : Colors.white70,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 18, color: Colors.white24),
                                    onPressed: () => _deleteHabit(key),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _stat('🔥', '$streak day streak'),
                                  const SizedBox(width: 16),
                                  _stat('✅', '$totalDone total'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _weekDots(logs),
                            ],
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

  Widget _stat(String emoji, String label) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _weekDots(List<String> logs) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();
    final weekday = now.weekday;
    return Row(
      children: List.generate(7, (i) {
        final offset = i - (weekday - 1);
        final day = now.add(Duration(days: offset));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final done = logs.contains(key);
        final isToday = offset == 0;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            children: [
              Text(days[i], style: TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? kPurple : Colors.white10,
                  border: isToday ? Border.all(color: kPurpleLight, width: 1.5) : null,
                ),
                child: done
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ],
          ),
        );
      }),
    );
  }
}
