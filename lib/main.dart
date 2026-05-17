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

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  int _index = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  final _screens = const [
    TasksScreen(),
    HabitsScreen(),
    TimerScreen(),
    CalendarScreen(),
  ];

  final _navItems = const [
    (Icons.check_circle_outline_rounded, Icons.check_circle_rounded, 'Tasks'),
    (Icons.repeat_rounded, Icons.repeat_rounded, 'Habits'),
    (Icons.timer_outlined, Icons.timer_rounded, 'Timer'),
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Calendar'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _switchTab(int i) async {
    if (i == _index) return;
    await _fadeCtrl.reverse();
    setState(() => _index = i);
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      extendBody: true,
      body: Stack(
        children: [
          const _AppBackground(),
          FadeTransition(opacity: _fade, child: _screens[_index]),
        ],
      ),
      bottomNavigationBar: _floatingNav(),
    );
  }

  Widget _floatingNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(28),
                  Colors.white.withAlpha(12),
                ],
              ),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.white.withAlpha(40), width: 1),
            ),
            child: Row(
              children: List.generate(_navItems.length, (i) {
                final selected = _index == i;
                final item = _navItems[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _switchTab(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selected ? kPurple.withAlpha(180) : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected ? item.$2 : item.$1,
                            color: selected ? Colors.white : Colors.white38,
                            size: 20,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected ? Colors.white : Colors.white38,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
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

class _AppBackground extends StatelessWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: kBgDeep),
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  kPurple.withAlpha(70),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF1E40AF).withAlpha(50),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
