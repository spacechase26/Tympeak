import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../theme.dart';
import '../widgets/glass_card.dart';

final _googleSignIn = GoogleSignIn(
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
    setState(() {
      _user = null;
      _events = [];
    });
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = await _user!.authentication;
      final token = auth.accessToken;
      final now = DateTime.now().toUtc();
      final end = now.add(const Duration(days: 30));
      final url = Uri.parse(
        'https://www.googleapis.com/calendar/v3/calendars/primary/events'
        '?timeMin=${now.toIso8601String()}'
        '&timeMax=${end.toIso8601String()}'
        '&singleEvents=true&orderBy=startTime&maxResults=50',
      );
      final res = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        setState(() => _events = items);
      } else {
        setState(() => _error = 'Failed to load events (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createEvent(String title, DateTime start, DateTime end) async {
    try {
      final auth = await _user!.authentication;
      final token = auth.accessToken;
      final body = json.encode({
        'summary': title,
        'start': {'dateTime': start.toUtc().toIso8601String(), 'timeZone': 'UTC'},
        'end': {'dateTime': end.toUtc().toIso8601String(), 'timeZone': 'UTC'},
      });
      final res = await http.post(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Event created!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCreateDialog() {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Event', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    final t = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(selectedDate),
                    );
                    if (t != null) {
                      setDlg(() => selectedDate =
                          DateTime(d.year, d.month, d.day, t.hour, t.minute));
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, yyyy · h:mm a').format(selectedDate),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPurple),
              onPressed: () {
                if (titleCtrl.text.isNotEmpty) {
                  _createEvent(
                    titleCtrl.text,
                    selectedDate,
                    selectedDate.add(const Duration(hours: 1)),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgDeep,
      floatingActionButton: _user != null
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              backgroundColor: kPurple,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Calendar', style: Theme.of(context).appBarTheme.titleTextStyle),
                  if (_user != null)
                    GestureDetector(
                      onTap: _signOut,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: _user!.photoUrl != null
                            ? NetworkImage(_user!.photoUrl!)
                            : null,
                        child: _user!.photoUrl == null
                            ? Text(_user!.displayName?[0] ?? '?',
                                style: const TextStyle(fontSize: 14))
                            : null,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: GlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 56, color: kPurpleLight),
                const SizedBox(height: 16),
                const Text(
                  'Connect Google Calendar',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'View and create events directly from Tympeak. Your data stays between you and Google.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kPurple));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white54)),
            TextButton(onPressed: _loadEvents, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 48, color: Colors.white12),
            const SizedBox(height: 12),
            const Text('No upcoming events', style: TextStyle(color: Colors.white38)),
            TextButton(onPressed: _loadEvents, child: const Text('Refresh')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: kPurple,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _events.length,
        itemBuilder: (_, i) {
          final event = _events[i];
          final startRaw = event['start']?['dateTime'] ?? event['start']?['date'];
          DateTime? start;
          try {
            start = DateTime.parse(startRaw ?? '');
          } catch (_) {}

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kPurple,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['summary'] ?? 'No title',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                        if (start != null)
                          Text(
                            DateFormat('EEE, MMM d · h:mm a').format(start.toLocal()),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
