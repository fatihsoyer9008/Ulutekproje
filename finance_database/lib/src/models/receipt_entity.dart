import 'package:isar/isar.dart';

part 'receipt_entity.g.dart';

/// OCR ile okunan fişin finans işlemiyle bağlantılı kalıcı özeti.
@collection
class ReceiptEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int transactionId;

  String? merchantName;
  late int totalAmountInMinor;
  DateTime? date;
  String? category;
  String currency = 'TRY';
  String? rawOcrText;
  late DateTime createdAt;
  late DateTime updatedAt;
}
