import 'dart:async';

import 'package:flutter/material.dart';

import '../api/scanner_ws.dart';
import '../widgets/berd_header.dart';

class BlocksScreen extends StatefulWidget {
  const BlocksScreen({super.key, required this.ws});

  final ScannerWsClient ws;

  @override
  State<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends State<BlocksScreen> {
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _blocks = [];
  int? _serviceId;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
  _dateCtrl.text = DateTime.now().toIso8601String().substring(0, 10);
    unawaited(_load());
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = await widget.ws.request('services.list', const {});
      final bl = await widget.ws.request('blocks.list', const {});
      final svcData = svc['data'];
      final blData = bl['data'];
      setState(() {
        if (svcData is Map && svcData['items'] is List) {
          _services = (svcData['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (blData is Map && blData['items'] is List) {
          _blocks = (blData['items'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBlock() async {
    final date = _dateCtrl.text.trim();
    if (date.isEmpty) {
      setState(() => _error = 'Datum fehlt');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = <String, dynamic>{
        'slot_date': date,
        'reason': _reasonCtrl.text.trim(),
      };
      if (_serviceId != null) payload['service_id'] = _serviceId;
      final time = _timeCtrl.text.trim();
      if (time.isNotEmpty) payload['start_time'] = time;
      await widget.ws.request('blocks.create', payload);
      await _load();
      _reasonCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Termin gesperrt')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteBlock(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sperre aufheben?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nein')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ja')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.ws.request('blocks.delete', {'id': id});
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: BerdHeader(showPaired: true),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Termine sperren',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: _serviceId,
                    decoration: const InputDecoration(
                      labelText: 'Dienst (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Alle Dienste')),
                      ..._services.map(
                        (s) => DropdownMenuItem(
                          value: s['id'] as int,
                          child: Text(s['name']?.toString() ?? 'Dienst'),
                        ),
                      ),
                    ],
                    onChanged: _busy ? null : (v) => setState(() => _serviceId = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Datum (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Uhrzeit (HH:MM, leer = ganzer Tag)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Grund (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => unawaited(_createBlock()),
                    child: const Text('Sperre anlegen'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
                    ),
                  const SizedBox(height: 24),
                  Text('Aktuelle Sperren', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_blocks.isEmpty)
                    const Text('Keine Sperren', style: TextStyle(color: Colors.grey)),
                  ..._blocks.take(30).map((b) {
                    final id = b['id'] as int? ?? 0;
                    final line = [
                      b['slot_date'],
                      if (b['start_time'] != null) b['start_time'],
                      if (b['service_name'] != null) '· ${b['service_name']}',
                      if (b['reason'] != null && '$b[reason]'.isNotEmpty) '· ${b['reason']}',
                    ].join(' ');
                    return ListTile(
                      title: Text(line),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _busy ? null : () => unawaited(_deleteBlock(id)),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}