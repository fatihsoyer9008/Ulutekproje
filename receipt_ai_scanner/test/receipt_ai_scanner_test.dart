import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

void main() {
  testWidgets('scanner screen can be constructed', (tester) async {
    const screen = ReceiptScannerScreen();
    expect(screen, isA<ReceiptScannerScreen>());
  });
}
