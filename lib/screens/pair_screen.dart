import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/scanner_api.dart';
import '../config.dart';
import '../widgets/berd_header.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _tokenCtrl = TextEditingController();
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );
  String? _error;
  bool _busy = false;
  bool _handlingScan = false;

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pair([String? fromScan]) async {
    final raw = fromScan ?? _tokenCtrl.text;
    final code = normalizePairCode(raw);
    if (code.length < 16) {
      setState(() => _error = 'Paar-Token zu kurz');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final base = await loadBookingBaseUrl();
      final token = await ScannerApi(base).pair(code);
      await saveDeviceToken(token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ScanScreen()),
      );
    } on ScannerApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_handlingScan || _busy) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.isEmpty) return;
    if (!raw.contains('SCAN-PAIR') && !raw.startsWith(pairPrefix)) {
      return;
    }
    _handlingScan = true;
    await _scannerCtrl.stop();
    await _pair(raw);
    _handlingScan = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const BerdHeader(showPaired: false),
            const SizedBox(height: 8),
            Text(
              'Scanner koppeln',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Im Dashboard: BERD → App Connect → Paar-QR erzeugen und hier scannen.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: MobileScanner(
                  controller: _scannerCtrl,
                  onDetect: _onDetect,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Paar-Token',
                hintText: 'LBB-SCAN-PAIR:…',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () => _pair(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF0A0A0A),
              ),
              child: Text(_busy ? 'Koppelt …' : 'Koppeln'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: const Text('Server-URL einstellen'),
            ),
          ],
        ),
      ),
    );
  }
}