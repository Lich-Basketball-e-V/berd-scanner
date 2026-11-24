import 'package:berd_scanner/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts', (tester) async {
    await tester.pumpWidget(const BerdScannerApp());
    expect(find.byType(BerdScannerApp), findsOneWidget);
  });
}