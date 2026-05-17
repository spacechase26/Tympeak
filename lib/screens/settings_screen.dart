import 'package:flutter/material.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_padding.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _confirmClear(BuildContext context, String label, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear $label?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete all your $label data.', style: const TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () { onConfirm(); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withAlpha(180), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 28, 24, navBottomPadding(context)),
          children: [
            // Header
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF475569), kPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
            ]),

            const SizedBox(height: 28),

            // App identity
            GlassCard(
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kPurple, Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tympeak', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Version 1.0.0', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ]),
              ]),
            ),

            const SizedBox(height: 20),
            _sectionLabel('Data'),
            const SizedBox(height: 10),

            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _tile(
                  context,
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: kPurple,
                  label: 'Clear Tasks',
                  sub: 'Delete all to-do items',
                  onTap: () => _confirmClear(context, 'tasks', () => Storage.todos.clear()),
                ),
                _divider(),
                _tile(
                  context,
                  icon: Icons.repeat_rounded,
                  iconColor: const Color(0xFF0891B2),
                  label: 'Clear Habits',
                  sub: 'Delete all habits and streaks',
                  onTap: () => _confirmClear(context, 'habits', () => Storage.habits.clear()),
                ),
                _divider(),
                _tile(
                  context,
                  icon: Icons.delete_sweep_rounded,
                  iconColor: Colors.red,
                  label: 'Clear All Data',
                  sub: 'Wipe everything',
                  onTap: () => _confirmClear(context, 'all', () {
                    Storage.todos.clear();
                    Storage.habits.clear();
                    Storage.pomodoro.clear();
                  }),
                  destructive: true,
                ),
              ]),
            ),

            const SizedBox(height: 20),
            _sectionLabel('About'),
            const SizedBox(height: 10),

            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _tile(context, icon: Icons.info_outline_rounded, iconColor: Colors.white38, label: 'Built with Flutter', sub: 'Open source UI toolkit by Google'),
                _divider(),
                _tile(context, icon: Icons.lock_outline_rounded, iconColor: Colors.white38, label: 'Privacy', sub: 'All data stays on your device'),
                _divider(),
                _tile(context, icon: Icons.calendar_today_rounded, iconColor: Colors.white38, label: 'Google Calendar', sub: 'Data synced directly with Google — we store nothing'),
              ]),
            ),

            const SizedBox(height: 32),
            Center(
              child: Text('Made with ♥ by Spacechase', style: TextStyle(color: Colors.white.withAlpha(30), fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Colors.white10, indent: 56);

  Widget _tile(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sub,
    VoidCallback? onTap,
    bool destructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: iconColor.withAlpha(20), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: destructive ? Colors.red : Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ])),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(20), size: 18),
        ]),
      ),
    );
  }
}
