import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_ai_scanner/receipt_ai_scanner.dart';

void main() {
  const warningText =
      'Tutar veya kurum adından tam emin olamadık, lütfen kontrol edin';

  Widget buildSubject(double score) => MaterialApp(
        home: Scaffold(
          body: ReceiptLowConfidenceWarning(confidenceScore: score),
        ),
      );

  testWidgets('shows the warning below the 70 percent threshold',
      (tester) async {
    await tester.pumpWidget(buildSubject(.69));

    expect(find.text(warningText), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('hides the warning at or above the threshold', (tester) async {
    await tester.pumpWidget(buildSubject(.70));

    expect(find.text(warningText), findsNothing);
  });
}
