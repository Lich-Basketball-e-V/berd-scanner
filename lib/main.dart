import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const BerdScannerApp());
}

class BerdScannerApp extends StatelessWidget {
  const BerdScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BERD Check-in',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A0A0A),
          brightness: Brightness.light,
          surface: const Color(0xFFF0F0EE),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0A0A0A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const HomeGate(),
    );
  }
}