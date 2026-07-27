import 'package:isar/isar.dart';

part 'transaction_entity.g.dart';

enum TransactionSource { ocrRegex, ocrLlm, manual }

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
}