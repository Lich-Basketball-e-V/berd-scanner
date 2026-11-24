import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fängt Tastatur-Wedge-Eingaben von Hand-Barcodescannern ab (Zeichen + Enter).
class HardwareScanField extends StatefulWidget {
  const HardwareScanField({
    super.key,
    required this.enabled,
    required this.onCode,
  });

  final bool enabled;
  final ValueChanged<String> onCode;

  @override
  State<HardwareScanField> createState() => _HardwareScanFieldState();
}

class _HardwareScanFieldState extends State<HardwareScanField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant HardwareScanField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _ctrl.text.trim();
    _ctrl.clear();
    if (raw.isEmpty || !widget.enabled) return;
    widget.onCode(raw);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.barcode_reader, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              widget.enabled
                  ? 'Barcode-Scanner bereit'
                  : 'Bitte warten …',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Code am Scanner auslösen oder unten manuell eingeben.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: true,
              showCursor: false,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.visiblePassword,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                labelText: 'Scan-Eingabe',
                labelStyle: TextStyle(color: Colors.grey.shade500),
                hintText: 'Warte auf Scan …',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFF1a1a1a),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
              ),
              onSubmitted: (_) => _submit(),
              onEditingComplete: _submit,
              inputFormatters: [
                TextInputFormatter.withFunction((old, neu) {
                  if (neu.text.contains('\n') || neu.text.contains('\r')) {
                    final code = neu.text.replaceAll(RegExp(r'[\r\n]'), '');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _ctrl.text = code;
                      _submit();
                    });
                    return TextEditingValue(
                      text: code,
                      selection: TextSelection.collapsed(offset: code.length),
                    );
                  }
                  return neu;
                }),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.enabled ? _submit : null,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Manuell prüfen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}