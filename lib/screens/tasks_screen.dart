import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import 'package:uuid/uuid.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();

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
      backgroundColor: kBgDeep,
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tasks', style: Theme.of(context).appBarTheme.titleTextStyle),
          ValueListenableBuilder(
            valueListenable: Storage.todos.listenable(),
            builder: (_, box, __) {
              final done = box.values.where((v) => (v as Map)['done'] == true).length;
              final total = box.length;
              return Text(
                '$done of $total done',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _inputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Add a task…',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onSubmitted: _addTodo,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_rounded, color: kPurpleLight),
              onPressed: () => _addTodo(_controller.text),
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
        final keys = box.keys.toList();
        if (keys.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 48, color: Colors.white12),
                const SizedBox(height: 12),
                const Text('Nothing to do!', style: TextStyle(color: Colors.white38)),
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: data['done'] as bool,
                      onChanged: (_) => _toggleTodo(key, data),
                      activeColor: kPurple,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    Expanded(
                      child: Text(
                        data['text'] as String,
                        style: TextStyle(
                          color: data['done'] == true ? Colors.white30 : Colors.white,
                          decoration: data['done'] == true ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white30,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white24),
                      onPressed: () => _deleteTodo(key),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
