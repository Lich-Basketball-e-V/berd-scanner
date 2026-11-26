import 'package:flutter/material.dart';

import '../api/scanner_api.dart';

class VerifyResultCard extends StatelessWidget {
  const VerifyResultCard({super.key, required this.result});

  final VerifyResult result;

  @override
  Widget build(BuildContext context) {
    final b = result.booking;
    final already = result.alreadyRedeemed;
    final ok = result.admissionGranted;

    Color bg;
    Color border;
    Color titleColor;
    String title;
    if (ok) {
      bg = const Color(0xFFECFDF3);
      border = const Color(0xFF86EFAC);
      titleColor = const Color(0xFF15803D);
      title = '✓ Entwertet — Einlass';
    } else if (already) {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFCD34D);
      titleColor = const Color(0xFFB45309);
      title = '⚠ Bereits entwertet';
    } else {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECACA);
      titleColor = const Color(0xFFB91C1C);
      title = '✗ Nicht gültig';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
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
              if (b['checked_in_at'] != null)
                _row('Entwertet', _formatCheckedIn(b['checked_in_at']?.toString())),
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

  String _formatCheckedIn(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final m = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})').firstMatch(raw);
    if (m != null) return '${m.group(1)} ${m.group(2)} Uhr';
    return raw;
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