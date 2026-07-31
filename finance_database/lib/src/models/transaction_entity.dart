import 'package:isar/isar.dart';

part 'transaction_entity.g.dart';

enum TransactionSource { ocrRegex, ocrLlm, manual }

enum TransactionType { expense, income }

enum TransactionCategory {
  market,
  ulasim,
  fatura,
  eglence,
  saglik,
  giyim,
  diger,
}

@collection
class TransactionEntity {
  Id id = Isar.autoIncrement;

  @Enumerated(EnumType.name)
  TransactionType transactionType = TransactionType.expense;

  /// Kuruş cinsinden (12,50 TL → 1250). Float hatasını önler.
  late int amountInMinor;

  @Enumerated(EnumType.name)
  late TransactionCategory category;

  late DateTime date;

  String? merchantName;

  @Enumerated(EnumType.name)
  late TransactionSource source;

  /// Ham OCR metni — kullanıcı gizlilik ayarından kapatılabilir.
  String? rawOcrText;

  String? note;

  late DateTime createdAt;
  late DateTime updatedAt;

  Map<String, dynamic> toJson() {
  return {
    'id': id,
    'transactionType': transactionType.name,
    'amountInMinor': amountInMinor,
    'category': category.name,
    'date': date.toIso8601String(),
    'merchantName': merchantName,
    'source': source.name,
    'rawOcrText': rawOcrText,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
}
