import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/scanner_api.dart';
import '../config.dart';
import '../widgets/berd_header.dart';
import '../widgets/verify_result_card.dart';
import 'pair_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manualCtrl = TextEditingController();
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
  );

  VerifyResult? _result;
  String? _error;
  bool _busy = false;
  String _lastCode = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _manualCtrl.dispose();
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify(String raw) async {
    final code = normalizeCheckInCode(raw);
    if (code.isEmpty) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inSeconds < 3) return;
    _lastCode = code;
    _lastAt = now;

    final deviceToken = await loadDeviceToken();
    if (deviceToken == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PairScreen()),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final base = await loadBookingBaseUrl();
      final result = await ScannerApi(base).verify(deviceToken, code);
      if (result.admissionGranted) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
      setState(() => _result = result);
    } on ScannerApiException catch (e) {
      setState(() {
        _error = e.message;
        _result = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _result = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.isEmpty) return;
    if (raw.startsWith(pairPrefix) || raw.contains('SCAN-PAIR')) return;
    _verify(raw);
  }

  Future<void> _unpair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entkoppeln?'),
        content: const Text(
          'Das Tablet muss danach erneut mit einem Paar-QR gekoppelt werden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Entkoppeln')),
        ],
      ),
    );
    if (ok != true) return;
    await saveDeviceToken(null);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PairScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Row(
                children: [
                  const Expanded(child: BerdHeader(showPaired: true)),
                  IconButton(
                    tooltip: 'Einstellungen',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  TextButton(onPressed: _unpair, child: const Text('Entkoppeln')),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Check-in scannen',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: MobileScanner(
                        controller: _scannerCtrl,
                        onDetect: _onDetect,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Code manuell',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () {
                                _verify(_manualCtrl.text);
                                _manualCtrl.clear();
                              },
                        child: const Text('Prüfen'),
                      ),
                    ],
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  if (_result != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: VerifyResultCard(result: _result!),
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