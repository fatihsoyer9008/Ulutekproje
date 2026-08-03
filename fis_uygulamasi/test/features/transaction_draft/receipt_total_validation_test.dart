import 'package:app_main/features/transaction_draft/model/receipt_total_validation.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReceiptTotalValidation', () {
    test('uses item totals before quantity and unit price', () {
      final validation = ReceiptTotalValidation.evaluate(
        mainReceiptTotalInMinor: 2550,
        items: const [
          ReceiptItem(
            name: 'Ürün',
            totalAmountInMinor: 2550,
            quantity: 10,
            unitPriceInMinor: 1,
          ),
        ],
      );

      expect(validation.calculatedItemsTotalInMinor, 2550);
      expect(validation.hasMismatch, isFalse);
    });

    test('calculates fractional quantities in minor units and detects mismatch', () {
      final validation = ReceiptTotalValidation.evaluate(
        mainReceiptTotalInMinor: 401,
        items: const [
          ReceiptItem(name: 'Peynir', quantity: 1.25, unitPriceInMinor: 320),
          ReceiptItem(name: 'Ekmek', quantity: 1, priceMinor: 100),
        ],
      );

      expect(validation.calculatedItemsTotalInMinor, 500);
      expect(validation.hasMismatch, isTrue);
    });

    test('does not validate when any item cannot be priced', () {
      final validation = ReceiptTotalValidation.evaluate(
        mainReceiptTotalInMinor: 100,
        items: const [ReceiptItem(name: 'Bilinmeyen')],
      );

      expect(validation.canValidate, isFalse);
      expect(validation.hasMismatch, isFalse);
    });
  });
}
