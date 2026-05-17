import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../data/storage.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/screen_padding.dart';
import 'note_editor_screen.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

String _todayKey()  => 'journal_${_dateKey(DateTime.now())}';
String _journalKey(DateTime d) => 'journal_${_dateKey(d)}';

Map<String, dynamic> _journalEntryOf(dynamic raw) {
  if (raw == null) return {'body': '', 'mood': null};
  if (raw is String) return {'body': raw, 'mood': null};
  return Map<String, dynamic>.from(raw as Map);
}

int _calcStreak(Box box) {
  int streak = 0;
  var date = DateTime.now();
  for (int i = 0; i < 366; i++) {
    final entry = _journalEntryOf(box.get(_journalKey(date)));
    final body  = entry['body'] as String? ?? '';
    if (body.trim().isNotEmpty) {
      streak++;
    } else if (i > 0) {
      break; // gap — streak ends
    }
    date = date.subtract(const Duration(days: 1));
  }
  return streak;
}

String _stripMd(String md) {
  var s = md;
  s = s.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'\*(.*?)\*'),     (m) => m.group(1) ?? '');
  s = s.replaceAllMapped(RegExp(r'`(.*?)`'),       (m) => m.group(1) ?? '');
  s = s.replaceAll(RegExp(r'^#{1,6}\s+',   multiLine: true), '');
  s = s.replaceAll(RegExp(r'^[-*]\s+',     multiLine: true), '• ');
  s = s.replaceAll(RegExp(r'^>\s+',        multiLine: true), '');
  s = s.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1) ?? '');
  return s.trim();
}

Color _accentColor(String c) => switch (c) {
  'purple' => kPurple,
  'blue'   => kBlue,
  'green'  => const Color(0xFF16A34A),
  'amber'  => const Color(0xFFF59E0B),
  _        => Colors.transparent,
};

const _kNoteColorKeys  = ['none', 'purple', 'blue', 'green', 'amber'];
const _kNoteColorPaint = [Colors.white24, kPurple, kBlue, Color(0xFF16A34A), Color(0xFFF59E0B)];

const _kMoods = [('😄','great'), ('🙂','good'), ('😐','okay'), ('😔','sad'), ('😤','rough')];

// ── Top level ─────────────────────────────────────────────────────────────────
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _header(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
              child: _tab == 0
                  ? const DailyJournalTab(key: ValueKey('j'))
                  : const QuickNotesTab(key: ValueKey('q')),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kPurple, Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        const Text('Notes', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
      ]),
      const SizedBox(height: 14),
      GlassCard(
        padding: const EdgeInsets.all(4),
        radius: 16,
        child: Row(children: [
          _tabBtn(0, Icons.menu_book_rounded,     'Journal'),
          _tabBtn(1, Icons.sticky_note_2_rounded, 'Quick Notes'),
        ]),
      ),
    ]),
  );

  Widget _tabBtn(int idx, IconData icon, String label) {
    final sel = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: sel ? kPurple : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: sel ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: sel ? Colors.white : Colors.white38, fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
          ]),
        ),
      ),
    );
  }
}

// ── Daily Journal ─────────────────────────────────────────────────────────────
class DailyJournalTab extends StatefulWidget {
  const DailyJournalTab({super.key});
  @override State<DailyJournalTab> createState() => _DailyJournalTabState();
}

class _DailyJournalTabState extends State<DailyJournalTab> {
  late final TextEditingController _ctrl;
  late DateTime _selected;
  String? _mood;
  Timer? _saveTimer;

  static final _days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));

  @override
  void initState() {
    super.initState();
    _selected = DateTime.now();
    final entry = _journalEntryOf(Storage.notes.get(_journalKey(_selected)));
    _mood  = entry['mood'] as String?;
    _ctrl  = TextEditingController(text: entry['body'] as String? ?? '');
    _ctrl.addListener(_schedule);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    _ctrl.dispose();
    super.dispose();
  }

  void _schedule() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    final key = _journalKey(_selected);
    final old = _journalEntryOf(Storage.notes.get(key));
    Storage.notes.put(key, {...old, 'body': _ctrl.text, 'mood': _mood, 'updatedAt': DateTime.now().toIso8601String()});
  }

  void _selectDate(DateTime date) {
    if (DateUtils.isSameDay(date, _selected)) return;
    _saveTimer?.cancel();
    _saveNow();
    final entry = _journalEntryOf(Storage.notes.get(_journalKey(date)));
    setState(() {
      _selected = date;
      _mood     = entry['mood'] as String?;
      _ctrl.text = entry['body'] as String? ?? '';
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.dark(primary: kPurple, surface: Color(0xFF1A1A2E))),
        child: child!,
      ),
    );
    if (d != null) _selectDate(d);
  }

  void _insertLinePrefix(String prefix) {
    final pos  = _ctrl.selection.isValid ? _ctrl.selection.baseOffset : _ctrl.text.length;
    final txt  = _ctrl.text;
    final ls   = txt.lastIndexOf('\n', pos > 0 ? pos - 1 : 0) + 1;
    final newT = txt.substring(0, ls) + prefix + txt.substring(ls);
    _ctrl.value = TextEditingValue(text: newT, selection: TextSelection.collapsed(offset: pos + prefix.length));
    _schedule();
  }

  void _wrapText(String pre, String suf) {
    final sel = _ctrl.selection;
    final txt = _ctrl.text;
    if (!sel.isValid || sel.isCollapsed) {
      final pos = sel.isValid ? sel.baseOffset : txt.length;
      _ctrl.value = TextEditingValue(
        text: txt.substring(0, pos) + pre + suf + txt.substring(pos),
        selection: TextSelection.collapsed(offset: pos + pre.length),
      );
    } else {
      final seg  = txt.substring(sel.start, sel.end);
      final newT = txt.replaceRange(sel.start, sel.end, '$pre$seg$suf');
      _ctrl.value = TextEditingValue(
        text: newT,
        selection: TextSelection.collapsed(offset: sel.start + pre.length + seg.length + suf.length),
      );
    }
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Date strip + streak
      ValueListenableBuilder(
        valueListenable: Storage.notes.listenable(),
        builder: (_, box, __) {
          final streak = _calcStreak(box);
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Row(children: [
              // Date chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _days.map((d) {
                    final isSel     = DateUtils.isSameDay(d, _selected);
                    final isToday   = DateUtils.isSameDay(d, DateTime.now());
                    final entry     = _journalEntryOf(box.get(_journalKey(d)));
                    final hasEntry  = (entry['body'] as String? ?? '').trim().isNotEmpty;
                    return GestureDetector(
                      onTap: () => _selectDate(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel ? kPurple : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? kPurple : (isToday ? Colors.white24 : Colors.white12)),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(DateFormat('E').format(d).substring(0, 1),
                            style: TextStyle(color: isSel ? Colors.white70 : Colors.white38, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text('${d.day}',
                            style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasEntry ? (isSel ? Colors.white : kPurpleLight) : Colors.transparent,
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList()),
                ),
              ),
              const SizedBox(width: 8),
              // Calendar + streak
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Colors.white54, size: 16),
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEA580C).withAlpha(80)),
                    ),
                    child: Text('🔥 $streak', style: const TextStyle(fontSize: 11, color: Color(0xFFFB923C))),
                  ),
                ],
              ]),
            ]),
          );
        },
      ),

      // Mood row
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Row(children: [
          const Text('Mood', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          ..._kMoods.map((m) {
            final sel = _mood == m.$2;
            return GestureDetector(
              onTap: () { setState(() => _mood = sel ? null : m.$2); _schedule(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: sel ? kPurple.withAlpha(60) : Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? kPurple : Colors.white12),
                ),
                child: Text(m.$1, style: const TextStyle(fontSize: 18)),
              ),
            );
          }),
        ]),
      ),

      // Text editor
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.7),
              decoration: InputDecoration(
                hintText: DateUtils.isSameDay(_selected, DateTime.now())
                    ? 'What\'s on your mind today…'
                    : 'What happened on ${DateFormat('MMMM d').format(_selected)}…',
                hintStyle: const TextStyle(color: Colors.white24),
                border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),

      // Markdown toolbar
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
        ),
        padding: EdgeInsets.fromLTRB(8, 6, 8,
            MediaQuery.of(context).viewInsets.bottom > 0 ? 6 : navBottomPadding(context) - 40 > 6 ? navBottomPadding(context) - 40 : 6),
        child: Row(children: [
          _tb('B', () => _wrapText('**', '**'), bold: true),
          _tb('I', () => _wrapText('*', '*'),   italic: true),
          _tb('H', () => _insertLinePrefix('## ')),
          _tb('•', () => _insertLinePrefix('- ')),
          _tb('`', () => _wrapText('`', '`'),   mono: true),
          _tb('❝', () => _insertLinePrefix('> ')),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: _ctrl,
            builder: (_, __, ___) {
              final wc = _ctrl.text.trim().isEmpty ? 0 : _ctrl.text.trim().split(RegExp(r'\s+')).length;
              return Text('$wc w', style: const TextStyle(color: Colors.white24, fontSize: 11));
            },
          ),
          const SizedBox(width: 8),
        ]),
      ),
    ]);
  }

  Widget _tb(String label, VoidCallback onTap, {bool bold = false, bool italic = false, bool mono = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 36, height: 34,
        child: Center(child: Text(label, style: TextStyle(
          color: Colors.white54, fontSize: 14,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          fontFamily: mono ? 'monospace' : null,
        )))),
    );
  }
}

// ── Quick Notes ───────────────────────────────────────────────────────────────
class QuickNotesTab extends StatefulWidget {
  const QuickNotesTab({super.key});
  @override State<QuickNotesTab> createState() => _QuickNotesTabState();
}

class _QuickNotesTabState extends State<QuickNotesTab> {
  final _searchCtrl = TextEditingController();
  String _filter = 'all'; // 'all' | 'pinned' | 'archived'
  String _query  = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<MapEntry<String, Map<String, dynamic>>> _filtered(Box box) {
    final all = box.keys
        .where((k) => k is String && !(k as String).startsWith('journal_'))
        .map((k) => MapEntry(k as String, Map<String, dynamic>.from(box.get(k) as Map)))
        .toList();

    List<MapEntry<String, Map<String, dynamic>>> result;
    switch (_filter) {
      case 'pinned':
        result = all.where((e) => e.value['pinned'] == true && e.value['archived'] != true).toList();
        break;
      case 'archived':
        result = all.where((e) => e.value['archived'] == true).toList();
        break;
      default:
        result = all.where((e) => e.value['archived'] != true).toList();
    }

    if (_query.isNotEmpty) {
      result = result.where((e) {
        final t = (e.value['title'] as String? ?? '').toLowerCase();
        final b = (e.value['body']  as String? ?? '').toLowerCase();
        return t.contains(_query) || b.contains(_query);
      }).toList();
    }

    result.sort((a, b) {
      if (_filter != 'archived') {
        final ap = a.value['pinned'] == true, bp = b.value['pinned'] == true;
        if (ap != bp) return ap ? -1 : 1;
      }
      final au = a.value['updatedAt'] as String? ?? a.value['createdAt'] as String? ?? '';
      final bu = b.value['updatedAt'] as String? ?? b.value['createdAt'] as String? ?? '';
      return bu.compareTo(au);
    });

    return result;
  }

  void _openEditor({String? key, Map<String, dynamic>? data}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => NoteEditorScreen(noteKey: key, data: data),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          radius: 14,
          child: Row(children: [
            const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search notes…',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none, isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () { _searchCtrl.clear(); },
                child: const Icon(Icons.close_rounded, color: Colors.white30, size: 16),
              ),
          ]),
        ),
      ),

      // Filter chips
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Row(children: [
          _chip('all',      'All'),
          const SizedBox(width: 8),
          _chip('pinned',   'Pinned'),
          const SizedBox(width: 8),
          _chip('archived', 'Archived'),
          const Spacer(),
          // + New note button
          GestureDetector(
            onTap: () => _openEditor(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: kPurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('New', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),

      // Notes list
      Expanded(
        child: ValueListenableBuilder(
          valueListenable: Storage.notes.listenable(),
          builder: (ctx, box, _) {
            final notes = _filtered(box);
            if (notes.isEmpty) return _empty();
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(24, 0, 24, navBottomPadding(ctx)),
              itemCount: notes.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NoteCard(
                  noteKey: notes[i].key,
                  data: notes[i].value,
                  searchQuery: _query,
                  onTap: () => _openEditor(key: notes[i].key, data: notes[i].value),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _chip(String val, String label) {
    final sel = _filter == val;
    return GestureDetector(
      onTap: () => setState(() => _filter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? kPurple : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? kPurple : Colors.white12),
        ),
        child: Text(label, style: TextStyle(
          color: sel ? Colors.white : Colors.white38,
          fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }

  Widget _empty() {
    final msg = switch (_filter) {
      'pinned'   => ('📌', 'No pinned notes', 'Pin a note to see it here'),
      'archived' => ('🗂', 'Archive is empty', 'Swipe a note right to archive it'),
      _          => ('✏️', 'No notes yet', 'Tap + New to write your first note'),
    };
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(msg.$1, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(msg.$2, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(msg.$3, style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ]),
    );
  }
}

// ── Note card ─────────────────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  final String noteKey;
  final Map<String, dynamic> data;
  final String searchQuery;
  final VoidCallback onTap;
  const _NoteCard({required this.noteKey, required this.data, required this.searchQuery, required this.onTap});

  Future<bool?> _confirmDelete(BuildContext ctx) => showDialog<bool>(
    context: ctx,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete note?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      content: const Text('This cannot be undone.', style: TextStyle(color: Colors.white54)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withAlpha(180), foregroundColor: Colors.white,
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Delete')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final title    = data['title'] as String?;
    final body     = data['body']  as String? ?? '';
    final preview  = _stripMd(body);
    final pinned   = data['pinned']   == true;
    final archived = data['archived'] == true;
    final color    = data['color'] as String? ?? 'none';
    final accent   = _accentColor(color);
    final updAt    = data['updatedAt'] as String? ?? data['createdAt'] as String? ?? '';
    final dateLabel = updAt.isNotEmpty ? DateFormat('MMM d').format(DateTime.parse(updAt.substring(0, 10))) : '';

    return Dismissible(
      key: Key(noteKey),
      // startToEnd = archive
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: kPurple.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.archive_rounded, color: kPurpleLight),
          const SizedBox(width: 6),
          const Text('Archive', style: TextStyle(color: kPurpleLight, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
      // endToStart = delete
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          // Archive: no confirm needed
          final updated = Map<String, dynamic>.from(data);
          updated['archived'] = !archived;
          await Storage.notes.put(noteKey, updated);
          return false;
        } else {
          // Delete: confirm
          final ok = await _confirmDelete(context);
          if (ok == true) await Storage.notes.delete(noteKey);
          return false;
        }
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          _showOptions(context, archived, pinned);
        },
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (accent != Colors.transparent)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (title != null)
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    if (title != null) const SizedBox(height: 3),
                    Text(preview.isEmpty ? '(empty)' : preview,
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: preview.isEmpty ? Colors.white24 : Colors.white70,
                        fontSize: 13, height: 1.5)),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (dateLabel.isNotEmpty)
                        Text(dateLabel, style: const TextStyle(color: Colors.white30, fontSize: 11)),
                      if (archived) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(10),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('archived', style: TextStyle(color: Colors.white30, fontSize: 10)),
                        ),
                      ],
                      const Spacer(),
                      if (pinned) const Icon(Icons.push_pin_rounded, size: 12, color: kPurpleLight),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext ctx, bool archived, bool pinned) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassCard(
        radius: 28,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _mopt(ctx, Icons.push_pin_outlined, pinned ? 'Unpin' : 'Pin to top', kPurple, () {
            Navigator.pop(ctx);
            final u = Map<String, dynamic>.from(data);
            u['pinned'] = !pinned;
            Storage.notes.put(noteKey, u);
          }),
          _mopt(ctx, archived ? Icons.unarchive_rounded : Icons.archive_rounded,
            archived ? 'Unarchive' : 'Archive', const Color(0xFF0891B2), () {
            Navigator.pop(ctx);
            final u = Map<String, dynamic>.from(data);
            u['archived'] = !archived;
            Storage.notes.put(noteKey, u);
          }),
          _mopt(ctx, Icons.delete_outline_rounded, 'Delete', Colors.red, () async {
            Navigator.pop(ctx);
            final ok = await showDialog<bool>(
              context: ctx,
              builder: (_) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('Delete note?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                content: const Text('This cannot be undone.', style: TextStyle(color: Colors.white54)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withAlpha(180), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Delete')),
                ],
              ),
            );
            if (ok == true) Storage.notes.delete(noteKey);
          }),
          SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
        ]),
      ),
    );
  }

  Widget _mopt(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
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
          Text(label, style: TextStyle(color: color == Colors.white54 ? Colors.white : color, fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
