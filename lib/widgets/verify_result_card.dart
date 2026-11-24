import 'package:flutter/material.dart';

import '../api/scanner_api.dart';

class VerifyResultCard extends StatelessWidget {
  const VerifyResultCard({super.key, required this.result});

  final VerifyResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.admissionGranted;
    final b = result.booking;
    return Material(
      color: ok ? const Color(0xFFECFDF3) : const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ok ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok ? '✓ Check-in gültig' : '✗ Nicht gültig',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ok ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  ),
            ),
            const SizedBox(height: 6),
            Text(result.message),
            if (b != null) ...[
              const SizedBox(height: 12),
              _row('Termin', _when(b)),
              _row('Dienst', b['kind_label']?.toString() ?? b['kind']?.toString()),
              _row('Kontakt', b['contact_name']?.toString()),
              _row('Buchung', '#${b['id']}'),
              if (b['players'] is List)
                _row(
                  'Spieler',
                  (b['players'] as List).map((e) => e.toString()).join(', '),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _when(Map<String, dynamic> b) {
    final date = b['slot_date']?.toString() ?? '';
    final start = b['start_time']?.toString() ?? '';
    if (date.isEmpty) return '—';
    return start.isNotEmpty ? '$date · $start' : date;
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}