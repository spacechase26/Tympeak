import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

final _googleSignIn = GoogleSignIn(
  serverClientId: '956728111742-d1ojl3kdtacctd6a5t9rpgsdreg67oc3.apps.googleusercontent.com',
  scopes: [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar.events',
  ],
);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  GoogleSignInAccount? _user;
  bool _loading = false;
  List<Map<String, dynamic>> _events = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() => _user = account);
      if (account != null) _loadEvents();
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _signIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (e) {
      setState(() => _error = 'Sign-in failed: $e');
    }
  }

  Future<void> _signOut() async {
    await _googleSignIn.signOut();
    setState(() { _user = null; _events = []; });
  }

  Future<void> _loadEvents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = await _user!.authentication;
      final token = auth.accessToken;
      final now = DateTime.now().toUtc();
      final end = now.add(const Duration(days: 30));
      final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events'
        '?timeMin=${Uri.encodeComponent(now.toIso8601String())}'
        '&timeMax=${Uri.encodeComponent(end.toIso8601String())}'
        '&singleEvents=true&orderBy=startTime&maxResults=50',
      );
      final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => _events = List<Map<String, dynamic>>.from(data['items'] ?? []));
      } else {
        setState(() => _error = 'Could not load events (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createEvent(String title, DateTime start) async {
    try {
      final auth = await _user!.authentication;
      final token = auth.accessToken;
      final end = start.add(const Duration(hours: 1));
      final body = json.encode({
        'summary': title,
        'start': {'dateTime': start.toUtc().toIso8601String(), 'timeZone': 'UTC'},
        'end': {'dateTime': end.toUtc().toIso8601String(), 'timeZone': 'UTC'},
      });
      final res = await http.post(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: body,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _loadEvents();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event created ✓')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: GlassCard(
            radius: 28,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('New Event', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Event title…',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPurple)),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) {
                    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                    if (t != null) setDlg(() => selectedDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                  child: Row(children: [
                    const Icon(Icons.schedule_rounded, color: kPurpleLight, size: 18),
                    const SizedBox(width: 10),
                    Text(DateFormat('EEE, MMM d · h:mm a').format(selectedDate), style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.isNotEmpty) {
                      _createEvent(titleCtrl.text, selectedDate);
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Create Event', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _user != null
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: kPurple,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('New Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF0891B2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Calendar', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8)),
              ]),
              if (_user != null)
                GestureDetector(
                  onTap: _signOut,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: _user!.photoUrl != null ? NetworkImage(_user!.photoUrl!) : null,
                    backgroundColor: kPurple.withAlpha(60),
                    child: _user!.photoUrl == null ? Text(_user!.displayName?[0] ?? '?', style: const TextStyle(color: Colors.white)) : null,
                  ),
                ),
            ]),
          ),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: GlassCard(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF16A34A), Color(0xFF0891B2)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Connect Google Calendar', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('View your schedule and create events. Your data goes directly to Google — nothing is stored anywhere else.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    elevation: 0,
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
              ],
            ]),
          ),
        ),
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator(color: kPurple, strokeWidth: 2));

    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 48),
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.white38), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        TextButton(onPressed: _loadEvents, child: const Text('Try again', style: TextStyle(color: kPurpleLight))),
      ]));
    }

    if (_events.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.event_available_rounded, size: 48, color: Colors.white12),
        const SizedBox(height: 12),
        const Text('No upcoming events', style: TextStyle(color: Colors.white38)),
        const SizedBox(height: 8),
        TextButton(onPressed: _loadEvents, child: const Text('Refresh', style: TextStyle(color: kPurpleLight))),
      ]));
    }

    String? lastDate;
    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: kPurple,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
        itemCount: _events.length,
        itemBuilder: (_, i) {
          final event = _events[i];
          final startRaw = event['start']?['dateTime'] ?? event['start']?['date'];
          DateTime? start;
          try { start = DateTime.parse(startRaw ?? '').toLocal(); } catch (_) {}
          final dateLabel = start != null ? DateFormat('EEEE, MMMM d').format(start) : null;
          final showDate = dateLabel != null && dateLabel != lastDate;
          if (showDate) lastDate = dateLabel;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                child: Text(dateLabel!, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 4, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kPurple, Color(0xFF9333EA)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(event['summary'] ?? 'No title', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (start != null) ...[
                      const SizedBox(height: 3),
                      Text(DateFormat('h:mm a').format(start), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ])),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
