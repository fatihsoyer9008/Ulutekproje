import 'package:finance_database/finance_database.dart';

/// Pure receipt-total validation logic, kept independent from Flutter widgets.
class ReceiptTotalValidation {
  const ReceiptTotalValidation._({
    required this.calculatedItemsTotalInMinor,
    required this.mainReceiptTotalInMinor,
  });

  final int? calculatedItemsTotalInMinor;
  final int? mainReceiptTotalInMinor;

  bool get canValidate =>
      calculatedItemsTotalInMinor != null && mainReceiptTotalInMinor != null;

  bool get hasMismatch =>
      canValidate && calculatedItemsTotalInMinor != mainReceiptTotalInMinor;

  static ReceiptTotalValidation evaluate({
    required Iterable<ReceiptItem> items,
    required int? mainReceiptTotalInMinor,
  }) {
    var calculatedTotal = 0;
    var hasItem = false;
    for (final item in items) {
      final itemTotal = _itemTotalInMinor(item);
      if (itemTotal == null) {
        return ReceiptTotalValidation._(
          calculatedItemsTotalInMinor: null,
          mainReceiptTotalInMinor: mainReceiptTotalInMinor,
        );
      }
      hasItem = true;
      calculatedTotal += itemTotal;
    }
    return ReceiptTotalValidation._(
      calculatedItemsTotalInMinor: hasItem ? calculatedTotal : null,
      mainReceiptTotalInMinor: mainReceiptTotalInMinor,
    );
  }

  static int? _itemTotalInMinor(ReceiptItem item) {
    if (item.totalAmountInMinor != null) return item.totalAmountInMinor;
    final unitPrice = item.unitPriceInMinor ?? item.priceMinor;
    final quantity = item.quantity;
    if (unitPrice == null || quantity == null || !quantity.isFinite) return null;

    // Convert the decimal quantity to a ratio, then multiply and round using
    // integer arithmetic. This keeps the monetary result in minor units.
    final ratio = _DecimalRatio.tryParse(quantity);
    if (ratio == null) return null;
    final numerator = BigInt.from(unitPrice) * ratio.numerator;
    final rounded = (numerator * BigInt.two + ratio.denominator) ~/
        (ratio.denominator * BigInt.two);
    return rounded.toInt();
  }
}

class _DecimalRatio {
  const _DecimalRatio(this.numerator, this.denominator);

  final BigInt numerator;
  final BigInt denominator;

  static _DecimalRatio? tryParse(double value) {
    if (value < 0 || !value.isFinite) return null;
    final text = value.toString();
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(text);
    if (match == null) return null;
    final fraction = match.group(2) ?? '';
    final denominator = BigInt.from(10).pow(fraction.length);
    return _DecimalRatio(
      BigInt.parse('${match.group(1)}$fraction'),
      denominator,
    );
  }
}
