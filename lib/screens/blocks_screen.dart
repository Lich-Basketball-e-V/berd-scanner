import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../api/scanner_ws.dart';
import '../widgets/berd_header.dart';

class _SlotDay {
  _SlotDay({required this.date, required this.weekdayLabel, required this.slots});

  final String date;
  final String weekdayLabel;
  final List<Map<String, dynamic>> slots;
}

class BlocksScreen extends StatefulWidget {
  const BlocksScreen({super.key, required this.ws});

  final ScannerWsClient ws;

  @override
  State<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends State<BlocksScreen> {
  static final DateFormat _keyFmt = DateFormat('yyyy-MM-dd');

  List<Map<String, dynamic>> _services = [];
  int? _serviceId;
  String? _serviceName;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  final Map<String, _SlotDay> _daysByDate = {};
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = await widget.ws.request('services.list', const {});
      final svcData = svc['data'];
      if (svcData is Map && svcData['items'] is List) {
        final list = (svcData['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _services = list;
          if (list.isNotEmpty) {
            _serviceId = list.first['id'] as int?;
            _serviceName = list.first['name']?.toString();
          }
        });
      }
      await _loadSlots();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadSlots() async {
    if (_serviceId == null) return;
    final from = _keyFmt.format(DateTime.now());
    final to = _keyFmt.format(DateTime.now().add(const Duration(days: 56)));
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await widget.ws.request('slots.list', {
        'service_id': _serviceId,
        'from': from,
        'to': to,
      });
      final data = res['data'];
      final days = data is Map ? data['days'] : null;
      final map = <String, _SlotDay>{};
      if (days is List) {
        for (final raw in days) {
          if (raw is! Map) continue;
          final date = raw['date']?.toString() ?? '';
          if (date.isEmpty) continue;
          final slots = (raw['slots'] is List)
              ? (raw['slots'] as List)
                  .map((s) => Map<String, dynamic>.from(s as Map))
                  .toList()
              : <Map<String, dynamic>>[];
          map[date] = _SlotDay(
            date: date,
            weekdayLabel: raw['weekday_label']?.toString() ?? '',
            slots: slots,
          );
        }
      }
      setState(() => _daysByDate
        ..clear()
        ..addAll(map));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleSlot(String date, String start, bool currentlyBlocked) async {
    final action = currentlyBlocked ? 'Sperre aufheben?' : 'Termin sperren?';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action),
        content: Text('$date · $start${_serviceName != null ? ' · $_serviceName' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await widget.ws.request('blocks.toggle', {
        'service_id': _serviceId,
        'slot_date': date,
        'start_time': start,
      });
      await _loadSlots();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyBlocked ? 'Sperre aufgehoben' : 'Termin gesperrt'),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int _blockedCountOn(String dateKey) {
    final day = _daysByDate[dateKey];
    if (day == null) return 0;
    return day.slots.where((s) => s['blocked'] == true).length;
  }

  @override
  Widget build(BuildContext context) {
    final selectedKey = _keyFmt.format(_selectedDay);
    final selectedDay = _daysByDate[selectedKey];
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: BerdHeader(showPaired: true),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    'Termine sperren',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Im Kalender einen Tag wählen und freie Slots antippen — erneut antippen hebt die Sperre auf.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  if (_services.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: _serviceId,
                      decoration: const InputDecoration(
                        labelText: 'Angebot',
                        border: OutlineInputBorder(),
                      ),
                      items: _services
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as int,
                              child: Text(s['name']?.toString() ?? 'Dienst'),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) {
                              setState(() {
                                _serviceId = v;
                                _serviceName = _services
                                    .cast<Map<String, dynamic>>()
                                    .firstWhere((s) => s['id'] == v)['name']
                                    ?.toString();
                              });
                              unawaited(_loadSlots());
                            },
                    ),
                  const SizedBox(height: 12),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: TableCalendar<void>(
                      firstDay: DateTime.now().subtract(const Duration(days: 1)),
                      lastDay: DateTime.now().add(const Duration(days: 90)),
                      focusedDay: _focusedDay,
                      locale: 'de_DE',
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      calendarFormat: CalendarFormat.month,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = DateTime(selected.year, selected.month, selected.day);
                          _focusedDay = focused;
                        });
                      },
                      onPageChanged: (focused) => setState(() => _focusedDay = focused),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final key = _keyFmt.format(date);
                          final n = _blockedCountOn(key);
                          if (n == 0) return null;
                          return Positioned(
                            bottom: 1,
                            child: Text(
                              '●',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.error,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                    ),
                  Row(
                    children: [
                      Text(
                        selectedDay != null
                            ? '${selectedDay.weekdayLabel} · $selectedKey'
                            : selectedKey,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _busy ? null : () => unawaited(_loadSlots()),
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Aktualisieren',
                      ),
                    ],
                  ),
                  _SlotLegend(),
                  const SizedBox(height: 12),
                  if (selectedDay == null || selectedDay.slots.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Keine buchbaren Slots an diesem Tag')),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: selectedDay.slots.map((slot) {
                        final start = slot['start']?.toString() ?? '';
                        final end = slot['end']?.toString() ?? '';
                        final past = slot['past'] == true;
                        final blocked = slot['blocked'] == true;
                        final taken = slot['taken'] == true && !blocked;
                        final available = slot['available'] == true;

                        Color bg;
                        Color fg;
                        String label;
                        VoidCallback? onTap;

                        if (past) {
                          bg = Colors.grey.shade200;
                          fg = Colors.grey.shade600;
                          label = '$start–$end';
                          onTap = null;
                        } else if (blocked) {
                          bg = const Color(0xFFFEE2E2);
                          fg = const Color(0xFFB91C1C);
                          label = '$start gesperrt';
                          onTap = () => unawaited(_toggleSlot(selectedKey, start, true));
                        } else if (taken) {
                          bg = const Color(0xFFFEF3C7);
                          fg = const Color(0xFFB45309);
                          label = '$start belegt';
                          onTap = null;
                        } else if (available) {
                          bg = const Color(0xFFD1FAE5);
                          fg = const Color(0xFF047857);
                          label = '$start–$end frei';
                          onTap = () => unawaited(_toggleSlot(selectedKey, start, false));
                        } else {
                          bg = Colors.grey.shade200;
                          fg = Colors.grey.shade700;
                          label = '$start–$end';
                          onTap = null;
                        }

                        return Material(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _busy ? null : onTap,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: fg,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget chip(String text, Color bg, Color fg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500)),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Frei', const Color(0xFFD1FAE5), const Color(0xFF047857)),
        chip('Gesperrt', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
        chip('Belegt', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
        chip('Vorbei', Colors.grey.shade200, Colors.grey.shade600),
      ],
    );
  }
}