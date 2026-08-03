import 'package:isar/isar.dart';

part 'receipt_line_item_entity.g.dart';

/// A product row belonging to a persisted receipt transaction.
///
/// Monetary values are kept in minor units (kuruş). [transactionId] acts as
/// the local foreign key because receipt rows have a lifecycle tied to their
/// parent transaction.
@collection
class ReceiptLineItemEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late int transactionId;

  late int position;
  late String name;
  String? category;
  int? priceInMinor;
  int? totalAmountInMinor;
  double? quantity;
  int? unitPriceInMinor;
  double? taxRate;
  int? taxAmountInMinor;

  Map<String, dynamic> toJson() => {
    'position': position,
    'name': name,
    'category': category,
    'priceInMinor': priceInMinor,
    'totalAmountInMinor': totalAmountInMinor,
    'quantity': quantity,
    'unitPriceInMinor': unitPriceInMinor,
    'taxRate': taxRate,
    'taxAmountInMinor': taxAmountInMinor,
  };
}
