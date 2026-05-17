import 'package:hive_flutter/hive_flutter.dart';

class Storage {
  static late Box<dynamic> _todos;
  static late Box<dynamic> _habits;
  static late Box<dynamic> _pomodoro;
  static late Box<dynamic> _notes;

  static Future<void> init() async {
    await Hive.initFlutter();
    _todos = await Hive.openBox('todos');
    _habits = await Hive.openBox('habits');
    _pomodoro = await Hive.openBox('pomodoro');
    _notes = await Hive.openBox('notes');
  }

  static Box<dynamic> get todos => _todos;
  static Box<dynamic> get habits => _habits;
  static Box<dynamic> get pomodoro => _pomodoro;
  static Box<dynamic> get notes => _notes;
}
