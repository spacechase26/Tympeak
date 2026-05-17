import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();
  bool _inputFocused = false;

  void _addTodo(String text) {
    if (text.trim().isEmpty) return;
    Storage.todos.put(_uuid.v4(), {
      'text': text.trim(),
      'done': false,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _controller.clear();
  }

  void _toggleTodo(String key, Map data) {
    Storage.todos.put(key, {...data, 'done': !data['done']});
  }

  void _deleteTodo(String key) {
    Storage.todos.delete(key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            _inputRow(),
            Expanded(child: _todoList()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: ValueListenableBuilder(
        valueListenable: Storage.todos.listenable(),
        builder: (_, box, __) {
          final done = box.values.where((v) => (v as Map)['done'] == true).length;
          final total = box.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPurple, Color(0xFF9333EA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('My Tasks', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
                ],
              ),
              const SizedBox(height: 10),
              if (total > 0) _progressBar(done, total),
            ],
          );
        },
      ),
    );
  }

  Widget _progressBar(int done, int total) {
    final pct = done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$done of $total completed', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text('${(pct * 100).round()}%', style: const TextStyle(color: kPurpleLight, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(kPurple),
          ),
        ),
      ],
    );
  }

  Widget _inputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        gradient: LinearGradient(
          colors: [
            _inputFocused ? kPurple.withAlpha(40) : Colors.white.withAlpha(18),
            Colors.white.withAlpha(6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        child: Row(
          children: [
            Icon(Icons.add_task_rounded, color: _inputFocused ? kPurpleLight : Colors.white30, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Focus(
                onFocusChange: (f) => setState(() => _inputFocused = f),
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Add a task…',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: _addTodo,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _addTodo(_controller.text),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: kPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _todoList() {
    return ValueListenableBuilder(
      valueListenable: Storage.todos.listenable(),
      builder: (_, box, __) {
        final allKeys = box.keys.toList();
        final pending = allKeys.where((k) => (box.get(k) as Map)['done'] == false).toList();
        final done = allKeys.where((k) => (box.get(k) as Map)['done'] == true).toList();

        if (allKeys.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kPurple.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: kPurpleLight, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('All clear!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Add a task above to get started', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          children: [
            ...pending.map((key) => _todoItem(key, Map<String, dynamic>.from(box.get(key)))),
            if (done.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Expanded(child: Divider(color: Colors.white12)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Completed (${done.length})', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                  ),
                  const Expanded(child: Divider(color: Colors.white12)),
                ]),
              ),
              ...done.map((key) => _todoItem(key, Map<String, dynamic>.from(box.get(key)), faded: true)),
            ],
          ],
        );
      },
    );
  }

  Widget _todoItem(String key, Map<String, dynamic> data, {bool faded = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(key),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(40),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        ),
        onDismissed: (_) => _deleteTodo(key),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggleTodo(key, data),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: data['done'] == true
                        ? const LinearGradient(colors: [kPurple, Color(0xFF9333EA)])
                        : null,
                    color: data['done'] == true ? null : Colors.transparent,
                    border: data['done'] == true
                        ? null
                        : Border.all(color: Colors.white30, width: 1.5),
                  ),
                  child: data['done'] == true
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  data['text'] as String,
                  style: TextStyle(
                    color: faded ? Colors.white30 : Colors.white,
                    fontSize: 15,
                    decoration: faded ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white30,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
