import 'package:flutter/material.dart';

class BerdHeader extends StatelessWidget {
  const BerdHeader({super.key, required this.showPaired});

  final bool showPaired;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/berd_logo.png', height: 36),
        const Spacer(),
        if (showPaired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'GEKOPPELT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
      ],
    );
  }
}