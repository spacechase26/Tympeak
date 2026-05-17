import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/notification_service.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_padding.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

const _kPrioColors = {
  'high':   Color(0xFFEF4444),
  'medium': Color(0xFFF59E0B),
  'low':    Color(0xFF3B82F6),
};
Color _prioColor(String p) => _kPrioColors[p] ?? Colors.transparent;

// ── Date / time helpers ───────────────────────────────────────────────────────
String _todayStr() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String _formatDate(String s) {
  final d = DateTime.tryParse(s);
  if (d == null) return s;
  final t = DateTime.now();
  if (d.year == t.year && d.month == t.month && d.day == t.day) return 'Today';
  final tom = t.add(const Duration(days: 1));
  if (d.year == tom.year && d.month == tom.month && d.day == tom.day) return 'Tomorrow';
  return DateFormat('MMM d').format(d);
}

String _fmtTime(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return hhmm;
  final h = int.tryParse(p[0]) ?? 0;
  final m = int.tryParse(p[1]) ?? 0;
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

// ── Notification scheduling helpers ──────────────────────────────────────────
Future<List<int>> _doScheduleNotifs(
    String key, String text, String? dueDate, String? reminderTime, List<int>? recurring) async {
  if (reminderTime == null) return [];
  final baseId = key.hashCode.abs() % 100000;
  final ids = <int>[];

  if (recurring != null && recurring.isNotEmpty) {
    for (final day in recurring) {
      final id = (baseId + day) % 100000;
      await NotificationService.scheduleRecurring(id, text, day, reminderTime);
      ids.add(id);
    }
  } else if (dueDate != null) {
    await NotificationService.scheduleReminder(baseId, text, dueDate, reminderTime);
    ids.add(baseId);
  }
  return ids;
}

Future<void> _doCancelNotifs(List<int>? ids) async {
  if (ids == null) return;
  await NotificationService.cancelAll(ids);
}

// ── Task data model ───────────────────────────────────────────────────────────
class _Task {
  final String key;
  final Map<String, dynamic> raw;
  _Task(this.key, Map r) : raw = Map<String, dynamic>.from(r);

  String   get text         => raw['text'] ?? '';
  bool     get done         => raw['done'] == true;
  bool     get pinned       => raw['pinned'] == true;
  String   get priority     => raw['priority'] ?? 'none';
  String?  get dueDate      => raw['dueDate'] as String?;
  String?  get reminderTime => raw['reminderTime'] as String?;
  String?  get lastDoneDate => raw['lastDoneDate'] as String?;
  DateTime get created      =>
      DateTime.tryParse(raw['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  List<int>? get recurring {
    final r = raw['recurring'];
    if (r == null) return null;
    return (r as List).map((e) => (e as num).toInt()).toList();
  }

  // Backward-compat: old tasks stored a single 'notifId' int
  List<int>? get notifIds {
    final n = raw['notifIds'];
    if (n != null) return (n as List).map((e) => (e as num).toInt()).toList();
    final old = raw['notifId'] as int?;
    return old != null ? [old] : null;
  }

  bool get isRecurring => recurring != null && recurring!.isNotEmpty;

  bool get effectiveDone {
    if (isRecurring) return lastDoneDate == _todayStr();
    return done;
  }

  bool get isDueToday {
    if (isRecurring) {
      return recurring!.contains(DateTime.now().weekday - 1); // 0=Mon..6=Sun
    }
    return dueDate != null && dueDate == _todayStr();
  }

  bool get isOverdue   => !isRecurring && !done && dueDate != null && dueDate!.compareTo(_todayStr()) < 0;
  bool get isDueFuture => !isRecurring && !done && dueDate != null && dueDate!.compareTo(_todayStr()) > 0;

  int get _dateOrder {
    if (isRecurring) return isDueToday ? 1 : 4;
    if (isOverdue)   return 0;
    if (isDueToday)  return 1;
    if (isDueFuture) return 2;
    return 3;
  }

  int get _prioOrder {
    switch (priority) {
      case 'high':   return 0;
      case 'medium': return 1;
      case 'low':    return 2;
      default:       return 3;
    }
  }

  static int compare(_Task a, _Task b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    if (a._dateOrder != b._dateOrder) return a._dateOrder.compareTo(b._dateOrder);
    if (a._prioOrder != b._prioOrder) return a._prioOrder.compareTo(b._prioOrder);
    return b.created.compareTo(a.created);
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int  _filterIdx   = 0;
  bool _initialized = false;
  int  _prevPending = 0;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() { _confetti.dispose(); super.dispose(); }

  List<_Task> _all(Box box) =>
      box.keys.map((k) => _Task(k as String, box.get(k))).toList();

  List<_Task> _filter(List<_Task> all) {
    switch (_filterIdx) {
      case 1: // Today — non-recurring pending (overdue/today/undated) + recurring due today not done
        return all.where((t) {
          if (t.isRecurring) return t.isDueToday && !t.effectiveDone;
          return !t.done && (t.isOverdue || t.isDueToday || t.dueDate == null);
        }).toList()
          ..sort(_Task.compare);

      case 2: // Upcoming — non-recurring future due date only
        return all
            .where((t) => !t.isRecurring && !t.done && t.isDueFuture)
            .toList()
          ..sort(_Task.compare);

      case 3: // Done — non-recurring done + recurring done today
        return all
            .where((t) => t.isRecurring ? (t.effectiveDone && t.isDueToday) : t.done)
            .toList()
          ..sort((a, b) => b.created.compareTo(a.created));

      default: // All
        final active = all.where((t) => !t.effectiveDone).toList()..sort(_Task.compare);
        final done   = all.where((t) =>  t.effectiveDone).toList()
          ..sort((a, b) => b.created.compareTo(a.created));
        return [...active, ...done];
    }
  }

  // For progress bar: recurring tasks only count if due today
  int _pendingCount(List<_Task> all) => all.where((t) {
    if (t.isRecurring) return t.isDueToday && !t.effectiveDone;
    return !t.done;
  }).length;

  int _doneCount(List<_Task> all) => all.where((t) {
    if (t.isRecurring) return t.isDueToday && t.effectiveDone;
    return t.done;
  }).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            _buildHeader(),
            const _AddRow(),
            Expanded(child: _buildList()),
          ]),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                kPurple, Color(0xFF0891B2), Color(0xFF16A34A),
                Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFFCA8A04), Colors.white,
              ],
              numberOfParticles: 40,
              gravity: 0.15,
              emissionFrequency: 0.05,
              maxBlastForce: 22,
              minBlastForce: 8,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return ValueListenableBuilder(
      valueListenable: Storage.todos.listenable(),
      builder: (_, box, __) {
        final all     = _all(box);
        final pending = _pendingCount(all);
        final done    = _doneCount(all);
        final total   = pending + done;
        final pct     = total > 0 ? done / total : 0.0;

        if (!_initialized) {
          _prevPending = pending;
          _initialized = true;
        } else if (total > 0 && pending == 0 && _prevPending > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _confetti.play();
          });
        }
        _prevPending = pending;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPurple, Color(0xFF9333EA)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('My Tasks',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
              const Spacer(),
              if (pending == 0 && total > 0)
                GlassBadge('Inbox zero 🎉', color: const Color(0xFF16A34A)),
            ]),
            if (total > 0) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$done of $total done',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Text('${(pct * 100).round()}%',
                  style: const TextStyle(color: kPurpleLight, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 4,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(pct == 1.0 ? const Color(0xFF16A34A) : kPurple),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _filterChips(),
          ]),
        );
      },
    );
  }

  Widget _filterChips() {
    const labels = ['All', 'Today', 'Upcoming', 'Done'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: List.generate(labels.length, (i) {
        final sel = _filterIdx == i;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _filterIdx = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? kPurple : Colors.white.withAlpha(12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? kPurple : Colors.white12),
              ),
              child: Text(labels[i],
                style: TextStyle(
                  color: sel ? Colors.white : Colors.white38,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                )),
            ),
          ),
        );
      })),
    );
  }

  Widget _buildList() {
    return ValueListenableBuilder(
      valueListenable: Storage.todos.listenable(),
      builder: (ctx, box, _) {
        final filtered = _filter(_all(box));
        if (filtered.isEmpty) return _EmptyState(filterIdx: _filterIdx);

        int separatorAt = -1;
        if (_filterIdx == 0) {
          final firstDone = filtered.indexWhere((t) => t.effectiveDone);
          if (firstDone > 0) separatorAt = firstDone;
        }

        final itemCount = filtered.length + (separatorAt >= 0 ? 1 : 0);
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(24, 12, 24, navBottomPadding(ctx)),
          itemCount: itemCount,
          itemBuilder: (_, i) {
            if (separatorAt >= 0) {
              if (i == separatorAt) {
                return _divider(filtered.where((t) => t.effectiveDone).length);
              }
              final idx = i < separatorAt ? i : i - 1;
              return _TaskItem(task: filtered[idx]);
            }
            return _TaskItem(task: filtered[i]);
          },
        );
      },
    );
  }

  Widget _divider(int doneCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        const Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Completed ($doneCount)',
            style: const TextStyle(color: Colors.white30, fontSize: 11)),
        ),
        const Expanded(child: Divider(color: Colors.white12)),
      ]),
    );
  }
}

// ── Add Row ───────────────────────────────────────────────────────────────────
class _AddRow extends StatefulWidget {
  const _AddRow();
  @override
  State<_AddRow> createState() => _AddRowState();
}

class _AddRowState extends State<_AddRow> {
  final _text = TextEditingController();
  final _uuid = const Uuid();

  bool     _focused      = false;
  bool     _expanded     = false;
  String   _priority     = 'none';
  String?  _dueDate;
  String?  _reminderTime;
  Set<int> _recurDays    = {};

  bool get _isRecurring => _recurDays.isNotEmpty;
  bool get _hasTimeTrigger => _isRecurring || _dueDate != null;

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;

    final key       = _uuid.v4();
    final recurring = _isRecurring ? List<int>.from(_recurDays) : null;
    final dueDate   = _isRecurring ? null : _dueDate;
    final ids       = await _doScheduleNotifs(key, text, dueDate, _reminderTime, recurring);

    Storage.todos.put(key, {
      'text':         text,
      'done':         false,
      'createdAt':    DateTime.now().toIso8601String(),
      'priority':     _priority,
      'pinned':       false,
      'dueDate':      dueDate,
      'reminderTime': _reminderTime,
      'recurring':    recurring,
      'lastDoneDate': null,
      'notifIds':     ids.isEmpty ? null : ids,
    });

    _text.clear();
    setState(() {
      _expanded     = false;
      _priority     = 'none';
      _dueDate      = null;
      _reminderTime = null;
      _recurDays    = {};
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: kPurple, surface: Color(0xFF1A1A2E)),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() {
        _dueDate   = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
        _recurDays = {};
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay initial = TimeOfDay.now();
    if (_reminderTime != null) {
      final p = _reminderTime!.split(':');
      initial = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: kPurple, surface: Color(0xFF1A1A2E)),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() => _reminderTime =
          '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        gradient: LinearGradient(colors: [
          _focused ? kPurple.withAlpha(40) : Colors.white.withAlpha(18),
          Colors.white.withAlpha(6),
        ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.add_task_rounded,
              color: _focused ? kPurpleLight : Colors.white30, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Focus(
                onFocusChange: (f) => setState(() => _focused = f),
                child: TextField(
                  controller: _text,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Add a task…',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none, isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _expanded ? 0.5 : 0,
                child: Icon(Icons.expand_more_rounded,
                  color: _expanded ? kPurpleLight : Colors.white30, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _submit,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 16),
              ),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _expanded ? _detailsPanel() : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }

  Widget _detailsPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 10),

        // Priority
        _label('Priority'),
        const SizedBox(height: 6),
        _priorityRow(),
        const SizedBox(height: 12),

        // Repeat days
        _label('Repeat'),
        const SizedBox(height: 6),
        _dayChips(),
        const SizedBox(height: 12),

        // Due date (hidden when recurring)
        if (!_isRecurring) ...[
          _label('Due Date'),
          const SizedBox(height: 6),
          Row(children: [
            GestureDetector(onTap: _pickDate, child: _dateChip()),
            if (_dueDate != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() { _dueDate = null; if (!_isRecurring) _reminderTime = null; }),
                child: const Icon(Icons.close_rounded, color: Colors.white30, size: 16),
              ),
            ],
          ]),
          const SizedBox(height: 12),
        ],

        // Reminder (only when there's a date or recurring to attach to)
        if (_hasTimeTrigger) ...[
          _label('Reminder'),
          const SizedBox(height: 6),
          Row(children: [
            GestureDetector(onTap: _pickTime, child: _timeChip()),
            if (_reminderTime != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() => _reminderTime = null),
                child: const Icon(Icons.close_rounded, color: Colors.white30, size: 16),
              ),
            ],
          ]),
        ],
      ]),
    );
  }

  Widget _label(String t) =>
      Text(t, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600));

  Widget _priorityRow() {
    return Row(children: [('none','None'),('high','High'),('medium','Med'),('low','Low')].map((t) {
      final sel = _priority == t.$1;
      final col = _prioColor(t.$1);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          onTap: () => setState(() => _priority = t.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: sel ? (col == Colors.transparent ? kPurple.withAlpha(60) : col.withAlpha(60)) : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? (col == Colors.transparent ? kPurple : col) : Colors.white12),
            ),
            child: Text(t.$2,
              style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }).toList());
  }

  Widget _dayChips() {
    return Row(children: List.generate(7, (i) {
      final sel = _recurDays.contains(i);
      return Padding(
        padding: const EdgeInsets.only(right: 5),
        child: GestureDetector(
          onTap: () => setState(() {
            if (_recurDays.contains(i)) { _recurDays.remove(i); }
            else { _recurDays.add(i); _dueDate = null; }
            if (!_isRecurring && _dueDate == null) _reminderTime = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32, height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? kPurple : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sel ? kPurple : Colors.white12),
            ),
            child: Text(_kDayLabels[i],
              style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }));
  }

  Widget _dateChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _dueDate != null ? kPurple.withAlpha(40) : Colors.white.withAlpha(8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _dueDate != null ? kPurple : Colors.white12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.calendar_today_rounded, size: 11,
        color: _dueDate != null ? kPurpleLight : Colors.white38),
      const SizedBox(width: 6),
      Text(_dueDate != null ? _formatDate(_dueDate!) : 'No date',
        style: TextStyle(color: _dueDate != null ? Colors.white : Colors.white38,
          fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _timeChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _reminderTime != null ? const Color(0xFF0891B2).withAlpha(55) : Colors.white.withAlpha(8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _reminderTime != null ? const Color(0xFF0891B2) : Colors.white12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.alarm_rounded, size: 11,
        color: _reminderTime != null ? const Color(0xFF38BDF8) : Colors.white38),
      const SizedBox(width: 6),
      Text(_reminderTime != null ? _fmtTime(_reminderTime!) : 'No reminder',
        style: TextStyle(color: _reminderTime != null ? Colors.white : Colors.white38,
          fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Task item ─────────────────────────────────────────────────────────────────
class _TaskItem extends StatelessWidget {
  final _Task task;
  const _TaskItem({required this.task});

  Future<void> _toggle() async {
    final data = Map<String, dynamic>.from(task.raw);
    if (task.isRecurring) {
      final nowDone = task.lastDoneDate != _todayStr();
      data['lastDoneDate'] = nowDone ? _todayStr() : null;
    } else {
      final nowDone = !task.done;
      data['done']        = nowDone;
      data['completedAt'] = nowDone ? DateTime.now().toIso8601String() : null;
      if (nowDone) {
        await _doCancelNotifs(task.notifIds);
      } else if (task.reminderTime != null) {
        final ids = await _doScheduleNotifs(
            task.key, task.text, task.dueDate, task.reminderTime, task.recurring);
        data['notifIds'] = ids.isEmpty ? null : ids;
      }
    }
    await Storage.todos.put(task.key, data);
    HapticFeedback.lightImpact();
  }

  Future<void> _delete() async {
    await _doCancelNotifs(task.notifIds);
    await Storage.todos.delete(task.key);
  }

  void _togglePin() {
    final data = Map<String, dynamic>.from(task.raw);
    data['pinned'] = !task.pinned;
    Storage.todos.put(task.key, data);
  }

  Future<bool?> _confirmDelete(BuildContext ctx) => showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete task?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: Text('"${task.text}"', style: const TextStyle(color: Colors.white54)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withAlpha(180), foregroundColor: Colors.white,
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  void _showOptions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassCard(
        radius: 28,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(task.text, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 14),
          _opt(ctx, Icons.edit_rounded, 'Edit', Colors.white54, () {
            Navigator.pop(ctx);
            showModalBottomSheet(
              context: ctx,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => _TaskEditSheet(task: task),
            );
          }),
          _opt(ctx,
            task.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            task.pinned ? 'Unpin' : 'Pin to top',
            kPurple,
            () { Navigator.pop(ctx); _togglePin(); }),
          _opt(ctx, Icons.delete_outline_rounded, 'Delete', Colors.red, () async {
            Navigator.pop(ctx);
            final ok = await _confirmDelete(ctx);
            if (ok == true) _delete();
          }),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _opt(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(
            color: color == Colors.white54 ? Colors.white : color,
            fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = task.isRecurring && !task.isDueToday;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(task.key),
        direction: DismissDirection.startToEnd,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(40),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        ),
        confirmDismiss: (_) async {
          final ok = await _confirmDelete(context);
          if (ok == true) await _delete();
          return false;
        },
        child: GestureDetector(
          onDoubleTap: () => _toggle(),
          onLongPress: () => _showOptions(context),
          child: Opacity(
            opacity: task.effectiveDone ? 0.52 : (dimmed ? 0.65 : 1.0),
            child: GlassCard(
              padding: EdgeInsets.zero,
              gradient: task.isOverdue && !task.done
                  ? LinearGradient(
                      colors: [Colors.red.withAlpha(22), Colors.white.withAlpha(6)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(width: 4, color: _prioColor(task.priority)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(children: [
                        // Checkbox
                        GestureDetector(
                          onTap: () => _toggle(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: task.effectiveDone
                                  ? const LinearGradient(colors: [kPurple, Color(0xFF9333EA)])
                                  : null,
                              border: task.effectiveDone
                                  ? null
                                  : Border.all(
                                      color: dimmed ? Colors.white12 : Colors.white30,
                                      width: 1.5),
                            ),
                            child: task.effectiveDone
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                color: task.effectiveDone ? Colors.white30 : Colors.white,
                                fontSize: 15,
                                decoration: task.effectiveDone
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: Colors.white30,
                              ),
                              child: Text(task.text),
                            ),
                            _metaRow(),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaRow() {
    final badges = <Widget>[];

    if (!task.isRecurring && task.dueDate != null) badges.add(_dueBadge());
    if (task.isRecurring) badges.add(_recurBadge());
    if (task.pinned) badges.add(const Icon(Icons.push_pin_rounded, size: 11, color: Colors.white38));
    if (task.reminderTime != null) {
      badges.add(Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.alarm_rounded, size: 10, color: Colors.white30),
        const SizedBox(width: 3),
        Text(_fmtTime(task.reminderTime!),
          style: const TextStyle(color: Colors.white30, fontSize: 10)),
      ]));
    }

    if (badges.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: badges),
    );
  }

  Widget _dueBadge() {
    String label;
    Color col;
    if (task.isOverdue) {
      final due  = DateTime.tryParse(task.dueDate!);
      final days = due != null
          ? DateTime.now().difference(DateTime(due.year, due.month, due.day)).inDays
          : 0;
      label = days == 1 ? 'Yesterday' : '${days}d late';
      col   = const Color(0xFFEF4444);
    } else if (task.isDueToday) {
      label = 'Today';
      col   = const Color(0xFFF59E0B);
    } else {
      label = _formatDate(task.dueDate!);
      col   = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: col.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withAlpha(60)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_today_rounded, size: 9, color: col),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _recurBadge() {
    final days   = task.recurring!..sort();
    final labels = days.map((d) => _kDayLabels[d]).join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: kPurple.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kPurple.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.repeat_rounded, size: 9, color: kPurpleLight),
        const SizedBox(width: 4),
        Text(labels, style: const TextStyle(color: kPurpleLight, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Task edit sheet ───────────────────────────────────────────────────────────
class _TaskEditSheet extends StatefulWidget {
  final _Task task;
  const _TaskEditSheet({required this.task});
  @override
  State<_TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends State<_TaskEditSheet> {
  late final TextEditingController _text;
  late String   _priority;
  late String?  _dueDate;
  late String?  _reminderTime;
  late Set<int> _recurDays;

  @override
  void initState() {
    super.initState();
    _text         = TextEditingController(text: widget.task.text);
    _priority     = widget.task.priority;
    _dueDate      = widget.task.dueDate;
    _reminderTime = widget.task.reminderTime;
    _recurDays    = Set<int>.from(widget.task.recurring ?? []);
  }

  @override
  void dispose() { _text.dispose(); super.dispose(); }

  bool get _isRecurring    => _recurDays.isNotEmpty;
  bool get _hasTimeTrigger => _isRecurring || _dueDate != null;

  Future<void> _pickDate() async {
    final initial = _dueDate != null ? (DateTime.tryParse(_dueDate!) ?? DateTime.now()) : DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: kPurple, surface: Color(0xFF1A1A2E)),
        ),
        child: child!,
      ),
    );
    if (d != null) {
      setState(() {
        _dueDate   = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
        _recurDays = {};
      });
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay initial = TimeOfDay.now();
    if (_reminderTime != null) {
      final p = _reminderTime!.split(':');
      initial = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: kPurple, surface: Color(0xFF1A1A2E)),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() => _reminderTime =
          '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}');
    }
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;

    await _doCancelNotifs(widget.task.notifIds);

    final recurring = _isRecurring ? List<int>.from(_recurDays) : null;
    final dueDate   = _isRecurring ? null : _dueDate;
    final ids       = await _doScheduleNotifs(widget.task.key, text, dueDate, _reminderTime, recurring);

    final data          = Map<String, dynamic>.from(widget.task.raw);
    data['text']        = text;
    data['priority']    = _priority;
    data['dueDate']     = dueDate;
    data['reminderTime']= _reminderTime;
    data['recurring']   = recurring;
    data['notifIds']    = ids.isEmpty ? null : ids;
    data.remove('notifId'); // remove legacy field

    await Storage.todos.put(widget.task.key, data);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassCard(
        radius: 28,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Edit Task',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Text
            TextField(
              controller: _text,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Task…',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true, fillColor: Colors.white.withAlpha(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kPurple)),
              ),
            ),
            const SizedBox(height: 16),

            // Priority
            _sheetLabel('Priority'),
            const SizedBox(height: 8),
            Row(children: [('none','None'),('high','High'),('medium','Med'),('low','Low')].map((t) {
              final sel = _priority == t.$1;
              final col = _prioColor(t.$1);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _priority = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? (col == Colors.transparent ? kPurple.withAlpha(60) : col.withAlpha(50)) : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? (col == Colors.transparent ? kPurple : col) : Colors.white12),
                    ),
                    child: Text(t.$2,
                      style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),

            // Repeat days
            _sheetLabel('Repeat'),
            const SizedBox(height: 8),
            Row(children: List.generate(7, (i) {
              final sel = _recurDays.contains(i);
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (_recurDays.contains(i)) { _recurDays.remove(i); }
                    else { _recurDays.add(i); _dueDate = null; }
                    if (!_isRecurring && _dueDate == null) _reminderTime = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? kPurple : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: sel ? kPurple : Colors.white12),
                    ),
                    child: Text(_kDayLabels[i],
                      style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            })),
            const SizedBox(height: 16),

            // Due date (hidden when recurring)
            if (!_isRecurring) ...[
              _sheetLabel('Due Date'),
              const SizedBox(height: 8),
              Row(children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _dueDate != null ? kPurple.withAlpha(40) : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _dueDate != null ? kPurple : Colors.white12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calendar_today_rounded, size: 13,
                        color: _dueDate != null ? kPurpleLight : Colors.white38),
                      const SizedBox(width: 8),
                      Text(_dueDate != null ? _formatDate(_dueDate!) : 'No date',
                        style: TextStyle(color: _dueDate != null ? Colors.white : Colors.white38,
                          fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() { _dueDate = null; if (!_isRecurring) _reminderTime = null; }),
                    child: const Icon(Icons.close_rounded, color: Colors.white30, size: 18),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
            ],

            // Reminder (when due date or recurring is set)
            if (_hasTimeTrigger) ...[
              _sheetLabel('Reminder'),
              const SizedBox(height: 8),
              Row(children: [
                GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _reminderTime != null
                          ? const Color(0xFF0891B2).withAlpha(50)
                          : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _reminderTime != null ? const Color(0xFF0891B2) : Colors.white12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.alarm_rounded, size: 13,
                        color: _reminderTime != null ? const Color(0xFF38BDF8) : Colors.white38),
                      const SizedBox(width: 8),
                      Text(_reminderTime != null ? _fmtTime(_reminderTime!) : 'No reminder',
                        style: TextStyle(
                          color: _reminderTime != null ? Colors.white : Colors.white38,
                          fontSize: 13, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                if (_reminderTime != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _reminderTime = null),
                    child: const Icon(Icons.close_rounded, color: Colors.white30, size: 18),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
            ],

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPurple, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
          ]),
        ),
      ),
    );
  }

  Widget _sheetLabel(String t) => Text(t,
    style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final int filterIdx;
  const _EmptyState({required this.filterIdx});

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = switch (filterIdx) {
      1 => (Icons.today_rounded,           'Nothing due today',   'You\'re all caught up!'),
      2 => (Icons.event_available_rounded, 'No upcoming tasks',   'Nothing scheduled ahead'),
      3 => (Icons.task_alt_rounded,        'No completed tasks',  'Finish something to see it here'),
      _ => (Icons.task_alt_rounded,        'All clear!',          'Add a task above to get started'),
    };
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: kPurple.withAlpha(20), shape: BoxShape.circle),
          child: Icon(icon, color: kPurpleLight, size: 32),
        ),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ]),
    );
  }
}
