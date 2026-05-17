import 'package:hive_flutter/hive_flutter.dart';

class Storage {
  static late Box<dynamic> _todos;
  static late Box<dynamic> _habits;
  static late Box<dynamic> _pomodoro;
  static late Box<dynamic> _notes;

  static Future<void> init() async {
    await Hive.initFlutter();
    await _openBoxes();
  }

  // Test entry point — uses an on-disk path instead of the Flutter
  // path_provider (which isn't available in unit tests).
  static Future<void> initForTest(String path) async {
    Hive.init(path);
    await _openBoxes();
  }

  static Future<void> _openBoxes() async {
    _todos    = await Hive.openBox('todos');
    _habits   = await Hive.openBox('habits');
    _pomodoro = await Hive.openBox('pomodoro');
    _notes    = await Hive.openBox('notes');
  }

  static Box<dynamic> get todos    => _todos;
  static Box<dynamic> get habits   => _habits;
  static Box<dynamic> get pomodoro => _pomodoro;
  static Box<dynamic> get notes    => _notes;
}
