import 'package:isar/isar.dart';

part 'receipt_entity.g.dart';

/// OCR ile okunan fişin işlem özetinden bağımsız kalıcı kaydı.
@collection
class ReceiptEntity {
  Id id = Isar.autoIncrement;

  String? merchantName;

  late int totalAmountInMinor;

  DateTime? date;

  String? category;

  String currency = 'TRY';

  String? rawOcrText;

  int? transactionId;

  late DateTime createdAt;
  late DateTime updatedAt;
}
