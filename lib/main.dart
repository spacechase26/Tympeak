import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/storage.dart';
import 'theme.dart';
import 'screens/tasks_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const TympeakApp());
}

class TympeakApp extends StatelessWidget {
  const TympeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tympeak',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    TasksScreen(),
    HabitsScreen(),
    TimerScreen(),
    CalendarScreen(),
  ];

  final _navItems = const [
    (Icons.check_circle_outline_rounded, Icons.check_circle_rounded, 'Tasks'),
    (Icons.loop_rounded, Icons.loop_rounded, 'Habits'),
    (Icons.timer_outlined, Icons.timer_rounded, 'Timer'),
    (Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Calendar'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      extendBody: true,
      body: Stack(
        children: [
          _backgroundGradient(),
          _screens[_index],
        ],
      ),
      bottomNavigationBar: _floatingNav(),
    );
  }

  Widget _backgroundGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.5, -0.8),
            radius: 1.2,
            colors: [
              kPurple.withAlpha(40),
              kBgDeep,
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0x44FFFFFF), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_navItems.length, (i) {
                final selected = _index == i;
                final item = _navItems[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _index = i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            selected ? item.$2 : item.$1,
                            key: ValueKey(selected),
                            color: selected ? kPurpleLight : Colors.white38,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.$3,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected ? kPurpleLight : Colors.white38,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
