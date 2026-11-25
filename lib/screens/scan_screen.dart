import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/scanner_api.dart';
import '../api/scanner_ws.dart';
import '../config.dart';
import '../widgets/berd_header.dart';
import '../widgets/hardware_scan_field.dart';
import '../widgets/verify_result_card.dart';
import 'blocks_screen.dart';
import 'pair_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  MobileScannerController? _scannerCtrl;
  ScanInputMode _inputMode = ScanInputMode.hardwareScanner;
  final ScannerWsClient _ws = ScannerWsClient();

  VerifyResult? _result;
  String? _error;
  bool _busy = false;
  String _lastCode = '';
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _ws.onRevoked = () async {
      await saveDeviceToken(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gerät wurde im Dashboard abgemeldet.')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PairScreen()),
      );
    };
    loadScanInputMode().then((mode) {
      if (!mounted) return;
      setState(() => _inputMode = mode);
      _syncCameraController();
    });
    unawaited(_connectWs());
  }

  Future<void> _connectWs() async {
    final deviceToken = await loadDeviceToken();
    if (deviceToken == null) return;
    try {
      final base = await loadBookingBaseUrl();
      final wsUrl = scannerWsUrlFromBookingBase(base);
      await _ws.connect(wsUrl, deviceToken);
    } catch (_) {
      /* HTTP-Fallback bei Verify */
    }
  }

  void _syncCameraController() {
    if (_inputMode == ScanInputMode.camera) {
      _scannerCtrl ??= MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [
          BarcodeFormat.qrCode,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
        ],
      );
    } else {
      _scannerCtrl?.dispose();
      _scannerCtrl = null;
    }
  }

  @override
  void dispose() {
    unawaited(_ws.disconnect());
    _scannerCtrl?.dispose();
    super.dispose();
  }

  Future<void> _setInputMode(ScanInputMode mode) async {
    if (_inputMode == mode) return;
    setState(() => _inputMode = mode);
    await saveScanInputMode(mode);
    _syncCameraController();
    setState(() {});
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
      final VerifyResult result;
      if (_ws.isConnected) {
        result = await _ws.verify(code);
      } else {
        final base = await loadBookingBaseUrl();
        result = await ScannerApi(base).verify(deviceToken, code);
      }
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

  void _onCameraDetect(BarcodeCapture capture) {
    if (_busy || _inputMode != ScanInputMode.camera) return;
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
    final camera = _scannerCtrl;

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
                    tooltip: 'Termine sperren',
                    onPressed: _ws.isConnected
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BlocksScreen(ws: _ws),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.event_busy_outlined),
                  ),
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
                  SegmentedButton<ScanInputMode>(
                    segments: const [
                      ButtonSegment(
                        value: ScanInputMode.hardwareScanner,
                        label: Text('Barcode-Scanner'),
                        icon: Icon(Icons.barcode_reader),
                      ),
                      ButtonSegment(
                        value: ScanInputMode.camera,
                        label: Text('Kamera'),
                        icon: Icon(Icons.photo_camera_outlined),
                      ),
                    ],
                    selected: {_inputMode},
                    onSelectionChanged: (selected) {
                      _setInputMode(selected.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_inputMode == ScanInputMode.hardwareScanner)
                    HardwareScanField(
                      enabled: !_busy,
                      onCode: _verify,
                    )
                  else if (camera != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: MobileScanner(
                          controller: camera,
                          onDetect: _onCameraDetect,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (_inputMode == ScanInputMode.camera)
                    Text(
                      'Barcode im Sichtfeld halten. Für USB-/Bluetooth-Scanner oben „Barcode-Scanner“ wählen.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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