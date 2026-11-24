import 'package:flutter/material.dart';

import '../config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  String? _notice;

  @override
  void initState() {
    super.initState();
    loadBookingBaseUrl().then((url) {
      if (mounted) _urlCtrl.text = url;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (!url.startsWith('http')) {
      setState(() => _notice = 'URL muss mit http:// oder https:// beginnen');
      return;
    }
    await saveBookingBaseUrl(url);
    setState(() => _notice = 'Gespeichert');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Buchungsportal (ohne /scanner)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://book.lbb.cylone.de',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Build-Default: $defaultBookingBaseUrl\n'
              'Oder beim Build: --dart-define=BOOKING_BASE_URL=…',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 12),
              Text(_notice!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF0A0A0A),
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}