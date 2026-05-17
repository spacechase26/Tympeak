import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';
import '../data/storage.dart';
import '../theme.dart';

class NoteEditorScreen extends StatefulWidget {
  final String? noteKey;
  final Map<String, dynamic>? data;
  const NoteEditorScreen({super.key, this.noteKey, this.data});
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late String? _noteKey;
  late String  _color;
  late bool    _pinned;
  late bool    _archived;
  late String  _createdAt;
  Timer? _saveTimer;
  bool _preview = false;

  @override
  void initState() {
    super.initState();
    _noteKey   = widget.noteKey;
    final d    = widget.data;
    _titleCtrl = TextEditingController(text: d?['title'] as String? ?? '');
    _bodyCtrl  = TextEditingController(text: d?['body']  as String? ?? '');
    _color     = d?['color']    as String? ?? 'none';
    _pinned    = d?['pinned']   == true;
    _archived  = d?['archived'] == true;
    _createdAt = d?['createdAt'] as String? ?? DateTime.now().toIso8601String();
    _titleCtrl.addListener(_schedule);
    _bodyCtrl.addListener(_schedule);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _flush();
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _schedule() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _flush);
  }

  void _flush() {
    final body  = _bodyCtrl.text;
    final title = _titleCtrl.text.trim();
    if (body.trim().isEmpty && title.isEmpty) return;
    _noteKey ??= const Uuid().v4();
    Storage.notes.put(_noteKey, {
      'title':     title.isEmpty ? null : title,
      'body':      body,
      'createdAt': _createdAt,
      'updatedAt': DateTime.now().toIso8601String(),
      'pinned':    _pinned,
      'archived':  _archived,
      'color':     _color,
    });
  }

  void _toggleArchive() {
    setState(() => _archived = !_archived);
    _flush();
    Navigator.pop(context);
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete note?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('This cannot be undone.',
          style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withAlpha(180), foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete')),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        _saveTimer?.cancel();
        if (_noteKey != null) Storage.notes.delete(_noteKey);
        if (mounted) Navigator.pop(context);
      }
    });
  }

  void _wrap(String pre, String suf) {
    final sel = _bodyCtrl.selection;
    final txt = _bodyCtrl.text;
    if (!sel.isValid || sel.isCollapsed) {
      final pos = sel.isValid ? sel.baseOffset : txt.length;
      _bodyCtrl.value = TextEditingValue(
        text: txt.substring(0, pos) + pre + suf + txt.substring(pos),
        selection: TextSelection.collapsed(offset: pos + pre.length),
      );
    } else {
      final seg = txt.substring(sel.start, sel.end);
      final newTxt = txt.replaceRange(sel.start, sel.end, '$pre$seg$suf');
      _bodyCtrl.value = TextEditingValue(
        text: newTxt,
        selection: TextSelection.collapsed(offset: sel.start + pre.length + seg.length + suf.length),
      );
    }
    _schedule();
  }

  void _linePrefix(String prefix) {
    final pos  = _bodyCtrl.selection.isValid ? _bodyCtrl.selection.baseOffset : _bodyCtrl.text.length;
    final txt  = _bodyCtrl.text;
    final ls   = txt.lastIndexOf('\n', pos > 0 ? pos - 1 : 0) + 1;
    final newT = txt.substring(0, ls) + prefix + txt.substring(ls);
    _bodyCtrl.value = TextEditingValue(
      text: newT,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
    _schedule();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) { if (didPop) { _saveTimer?.cancel(); _flush(); } },
      child: Scaffold(
        backgroundColor: kBgDeep,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(_preview ? Icons.edit_rounded : Icons.visibility_rounded,
                color: Colors.white54, size: 20),
              onPressed: () => setState(() => _preview = !_preview),
              tooltip: _preview ? 'Edit' : 'Preview markdown',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
              color: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (v) { if (v == 'archive') _toggleArchive(); if (v == 'delete') _confirmDelete(); },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'archive', child: Row(children: [
                  Icon(_archived ? Icons.unarchive_rounded : Icons.archive_rounded,
                    color: kPurpleLight, size: 18),
                  const SizedBox(width: 10),
                  Text(_archived ? 'Unarchive' : 'Archive',
                    style: const TextStyle(color: Colors.white)),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ])),
              ],
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: TextField(
              controller: _titleCtrl,
              enabled: !_preview,
              style: const TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w700, letterSpacing: -0.5),
              decoration: const InputDecoration(
                hintText: 'Title',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 22, fontWeight: FontWeight.w700),
                border: InputBorder.none, isDense: true,
              ),
            ),
          ),
          const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
          Expanded(
            child: _preview
                ? Markdown(
                    data: _bodyCtrl.text.isEmpty ? '*Nothing to preview*' : _bodyCtrl.text,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    styleSheet: MarkdownStyleSheet(
                      p:        const TextStyle(color: Colors.white70, fontSize: 15, height: 1.7),
                      h1:       const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      h2:       const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      h3:       const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      strong:   const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      em:       const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                      code:     TextStyle(color: kPurpleLight, backgroundColor: kPurple.withAlpha(30), fontFamily: 'monospace', fontSize: 13),
                      listBullet: const TextStyle(color: kPurpleLight),
                      blockquote: const TextStyle(color: Colors.white54, fontSize: 15),
                      blockquoteDecoration: BoxDecoration(
                        color: kPurple.withAlpha(15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: TextField(
                      controller: _bodyCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.7),
                      decoration: const InputDecoration(
                        hintText: 'Write… (markdown supported)',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: InputBorder.none, isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
          ),
          if (!_preview) _toolbar(),
        ]),
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
      ),
      padding: EdgeInsets.fromLTRB(8, 6, 8,
          MediaQuery.of(context).viewInsets.bottom > 0 ? 6 : MediaQuery.of(context).viewPadding.bottom + 6),
      child: Row(children: [
        _tb('B',  () => _wrap('**', '**'),  bold: true),
        _tb('I',  () => _wrap('*', '*'),    italic: true),
        _tb('H',  () => _linePrefix('## ')),
        _tb('•',  () => _linePrefix('- ')),
        _tb('`',  () => _wrap('`', '`'),    mono: true),
        _tb('❝',  () => _linePrefix('> ')),
        const Spacer(),
        ValueListenableBuilder(
          valueListenable: _bodyCtrl,
          builder: (_, __, ___) {
            final wc = _bodyCtrl.text.trim().isEmpty ? 0
                : _bodyCtrl.text.trim().split(RegExp(r'\s+')).length;
            return Text('$wc w', style: const TextStyle(color: Colors.white24, fontSize: 11));
          },
        ),
        const SizedBox(width: 8),
      ]),
    );
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
