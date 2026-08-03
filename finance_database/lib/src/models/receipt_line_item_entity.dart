import 'package:isar/isar.dart';

part 'receipt_line_item_entity.g.dart';

/// Bir fişe ait tek ürün satırı. Para alanları kuruş, miktar binde bir birimdir.
@collection
class ReceiptLineItemEntity {
  Id id = Isar.autoIncrement;

  @Index()
  late int receiptId;

  late String name;

  /// Satırın fişte görünen toplam tutarı.
  late int totalAmountInMinor;

  /// 1000 değeri 1 adet, 1500 değeri 1,5 birim anlamına gelir.
  int quantityInMillis = 1000;

  int? unitPriceInMinor;

  /// 1800 değeri %18 vergi oranı anlamına gelir.
  int? taxRateInBasisPoints;

  String? category;

  late DateTime createdAt;
  late DateTime updatedAt;
}
