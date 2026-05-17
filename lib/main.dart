import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/storage.dart';
import 'data/notification_service.dart';
import 'theme.dart';
import 'screens/tasks_screen.dart';
import 'screens/habits_screen.dart';
import 'screens/timer_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  await NotificationService.init();
  await NotificationService.requestPermissions();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
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
    NotesScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    (Icons.check_circle_outline_rounded, Icons.check_circle_rounded, 'Tasks'),
    (Icons.repeat_rounded,               Icons.repeat_rounded,        'Habits'),
    (Icons.timer_outlined,               Icons.timer_rounded,         'Timer'),
    (Icons.edit_note_outlined,            Icons.edit_note_rounded,     'Notes'),
    (Icons.settings_outlined,            Icons.settings_rounded,      'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
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
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: kBgDeep,
      extendBody: true,
      body: Stack(
        children: [
          const _AppBackground(),
          // Reserve nav-bar space at the screen-content level so no screen
          // ever paints behind the floating nav. 62 nav + 12 outer margin
          // + 12 buffer + system inset.
          Padding(
            padding: EdgeInsets.only(bottom: 86 + bottomInset),
            child: FadeTransition(opacity: _fade, child: _screens[_index]),
          ),
        ],
      ),
      bottomNavigationBar: _floatingNav(bottomInset),
    );
  }

  Widget _floatingNav(double bottomInset) {
    return Padding(
      // bottomInset accounts for the phone's system nav bar (gesture bar or buttons)
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withAlpha(30), Colors.white.withAlpha(12)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withAlpha(36), width: 1),
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
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? kPurple.withAlpha(200) : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected ? item.$2 : item.$1,
                            color: selected ? Colors.white : Colors.white38,
                            size: 19,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 9,
                              color: selected ? Colors.white : Colors.white38,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
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
      child: Stack(children: [
        Container(color: kBgDeep),
        Positioned(
          top: -100, left: -60,
          child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [kPurple.withAlpha(60), Colors.transparent]),
            ),
          ),
        ),
        Positioned(
          bottom: 120, right: -80,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [kBlue.withAlpha(45), Colors.transparent]),
            ),
          ),
        ),
      ]),
    );
  }
}
