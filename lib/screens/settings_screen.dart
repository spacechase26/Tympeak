import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../data/notification_service.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_padding.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _notifEnabled;

  @override
  void initState() {
    super.initState();
    _refreshNotifStatus();
  }

  Future<void> _refreshNotifStatus() async {
    final ok = await NotificationService.areNotificationsEnabled();
    if (mounted) setState(() => _notifEnabled = ok);
  }

  Future<void> _testNotification() async {
    await NotificationService.showTimerAlertNow(
      999999, '🔔 Test notification', 'If you can see and hear this, alerts work.');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test notification fired — check the tray.')));
  }

  Future<void> _testScheduled() async {
    await NotificationService.scheduleTimerAlert(
      999998, '⏳ Scheduled test (30s)',
      'Fired by the alarm scheduler — if you don\'t see this, battery saver is blocking alarms.',
      30);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scheduled — lock the phone and wait 30s.')));
  }

  Future<void> _requestPerms() async {
    await NotificationService.requestPermissions();
    await _refreshNotifStatus();
  }

  void _showBatteryHelp() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Allow background alerts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          'If timer / pomodoro / task notifications only fire when the app is '
          'open, your phone is killing scheduled alarms in the background.\n\n'
          'Open phone Settings, then:\n\n'
          '• Apps → Tympeak → Battery → Unrestricted (or "No restrictions")\n'
          '• Apps → Tympeak → Autostart → Enabled (Xiaomi / MIUI only)\n'
          '• Apps → Tympeak → Notifications → keep all channels enabled\n\n'
          'Once that\'s done, hit "Schedule test" to verify.',
          style: TextStyle(color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: kPurpleLight)),
          ),
        ],
      ),
    );
  }

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

  String _q(String s) => '"${s.replaceAll('"', '""')}"';

  List<String> _parseCsvRow(String row) {
    final result = <String>[];
    var i = 0;
    while (i < row.length) {
      if (row[i] == '"') {
        i++;
        final buf = StringBuffer();
        while (i < row.length) {
          if (row[i] == '"' && i + 1 < row.length && row[i + 1] == '"') {
            buf.write('"'); i += 2;
          } else if (row[i] == '"') {
            i++; break;
          } else {
            buf.write(row[i++]);
          }
        }
        result.add(buf.toString());
        if (i < row.length && row[i] == ',') i++;
      } else {
        final end = row.indexOf(',', i);
        if (end == -1) { result.add(row.substring(i)); break; }
        result.add(row.substring(i, end));
        i = end + 1;
      }
    }
    return result;
  }

  Future<void> _exportCsv(BuildContext context) async {
    final box = Storage.habits;
    if (box.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No habits to export')));
      return;
    }
    final buf = StringBuffer();
    buf.writeln('name,emoji,color,type,target,schedule,customDays,createdAt,logs');
    for (final key in box.keys) {
      final raw = box.get(key) as Map?;
      if (raw == null) continue;
      final rawLogs = raw['logs'];
      Map<String, int> logs;
      if (rawLogs is List) {
        logs = { for (final d in rawLogs) d.toString(): 1 };
      } else if (rawLogs is Map) {
        logs = rawLogs.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      } else {
        logs = {};
      }
      final logsStr = logs.entries.map((e) => '${e.key}=${e.value}').join('|');
      final customDays = List<int>.from(raw['customDays'] ?? [1, 2, 3, 4, 5, 6, 7]);
      buf.writeln([
        _q(raw['name']?.toString() ?? ''),
        _q(raw['emoji']?.toString() ?? '⭐'),
        _q('${raw['color'] ?? 0xFF7C3AED}'),
        _q(raw['type']?.toString() ?? 'yes_no'),
        _q('${raw['target'] ?? 1}'),
        _q(raw['schedule']?.toString() ?? 'daily'),
        _q(customDays.join('|')),
        _q(raw['createdAt']?.toString() ?? ''),
        _q(logsStr),
      ].join(','));
    }
    final tmp = File('${Directory.systemTemp.path}/tympeak_habits.csv');
    await tmp.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(tmp.path)], text: 'Tympeak habits export');
  }

  Future<void> _exportNotes(BuildContext context) async {
    final box = Storage.notes;
    if (box.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No notes to export')));
      return;
    }
    final Map<String, dynamic> data = {};
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map) {
        data[key.toString()] = Map<String, dynamic>.from(val);
      } else if (val is String) {
        data[key.toString()] = val;
      }
    }
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final tmp = File('${Directory.systemTemp.path}/tympeak_notes.json');
    await tmp.writeAsString(json);
    await Share.shareXFiles([XFile(tmp.path)], text: 'Tympeak notes export');
  }

  Future<void> _importNotes(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    try {
      final content = await File(path).readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      int count = 0;
      for (final entry in decoded.entries) {
        await Storage.notes.put(entry.key, entry.value);
        count++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count note${count == 1 ? '' : 's'}')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid notes backup file')));
      }
    }
  }

  Future<void> _importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    final path = result.files.single.path;
    if (path == null) return;
    final lines = await File(path).readAsLines();
    if (lines.length < 2) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No habits found in file')));
      return;
    }
    int count = 0;
    const uuid = Uuid();
    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final fields = _parseCsvRow(lines[i]);
      if (fields.length < 8) continue;
      final name = fields[0];
      if (name.isEmpty) continue;
      final logsStr = fields.length > 8 ? fields[8] : '';
      final logs = <String, int>{};
      if (logsStr.isNotEmpty) {
        for (final pair in logsStr.split('|')) {
          final parts = pair.split('=');
          if (parts.length == 2) logs[parts[0]] = int.tryParse(parts[1]) ?? 0;
        }
      }
      final customDays = fields[6].isEmpty
          ? [1, 2, 3, 4, 5, 6, 7]
          : fields[6].split('|').map((s) => int.tryParse(s) ?? 1).toList();
      await Storage.habits.put(uuid.v4(), {
        'name': name,
        'emoji': fields[1],
        'color': int.tryParse(fields[2]) ?? 0xFF7C3AED,
        'type': fields[3],
        'target': int.tryParse(fields[4]) ?? 1,
        'schedule': fields[5],
        'customDays': customDays,
        'createdAt': fields[7],
        'logs': logs,
      });
      count++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count habit${count == 1 ? '' : 's'}')));
    }
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('icon_source.png', width: 52, height: 52, fit: BoxFit.cover),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Tympeak', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Made with ♥ by Spacechase',
                      style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12)),
                    const SizedBox(height: 1),
                    const Text('Version 1.0.0', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ]),
                ),
              ]),
            ),

            const SizedBox(height: 20),
            _sectionLabel('Notifications'),
            const SizedBox(height: 10),

            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _tile(
                  context,
                  icon: _notifEnabled == true ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                  iconColor: _notifEnabled == true ? const Color(0xFF16A34A) : Colors.amber,
                  label: _notifEnabled == true ? 'Notifications enabled' : 'Notifications disabled',
                  sub: _notifEnabled == true
                      ? 'Tap to send an instant test alert'
                      : 'Tap to grant permission',
                  onTap: _notifEnabled == true ? _testNotification : _requestPerms,
                ),
                _divider(),
                _tile(
                  context,
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFF0891B2),
                  label: 'Schedule test (30s)',
                  sub: 'Verifies that background alerts still fire',
                  onTap: _testScheduled,
                ),
                _divider(),
                _tile(
                  context,
                  icon: Icons.battery_saver_rounded,
                  iconColor: Colors.amber,
                  label: 'Background alerts not working?',
                  sub: 'Disable battery optimization for Tympeak',
                  onTap: _showBatteryHelp,
                ),
                if (NotificationService.lastError != null) ...[
                  _divider(),
                  _tile(
                    context,
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                    label: 'Last error',
                    sub: NotificationService.lastError!,
                  ),
                ],
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
                    Storage.notes.clear();
                  }),
                  destructive: true,
                ),
              ]),
            ),

            const SizedBox(height: 16),
            _sectionLabel('Habits Backup'),
            const SizedBox(height: 10),

            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _tile(
                  context,
                  icon: Icons.upload_rounded,
                  iconColor: const Color(0xFF16A34A),
                  label: 'Export Habits',
                  sub: 'Save habits as CSV file',
                  onTap: () => _exportCsv(context),
                ),
                _divider(),
                _tile(
                  context,
                  icon: Icons.download_rounded,
                  iconColor: const Color(0xFF0891B2),
                  label: 'Import Habits',
                  sub: 'Load habits from CSV file',
                  onTap: () => _importCsv(context),
                ),
              ]),
            ),

            const SizedBox(height: 16),
            _sectionLabel('Notes Backup'),
            const SizedBox(height: 10),

            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _tile(
                  context,
                  icon: Icons.upload_rounded,
                  iconColor: const Color(0xFF16A34A),
                  label: 'Export Notes',
                  sub: 'Save notes & journal as JSON',
                  onTap: () => _exportNotes(context),
                ),
                _divider(),
                _tile(
                  context,
                  icon: Icons.download_rounded,
                  iconColor: const Color(0xFF0891B2),
                  label: 'Import Notes',
                  sub: 'Restore notes from JSON backup',
                  onTap: () => _importNotes(context),
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
                _tile(context, icon: Icons.lock_outline_rounded, iconColor: Colors.white38, label: 'Privacy', sub: 'All data stays on your device — no cloud sync'),
              ]),
            ),

            const SizedBox(height: 24),
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
