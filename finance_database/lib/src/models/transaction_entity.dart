import 'package:isar/isar.dart';

import 'receipt_line_item_entity.dart';

part 'transaction_entity.g.dart';

enum TransactionSource { ocrRegex, ocrLlm, manual }

enum TransactionType { expense, income }

enum SyncState { localOnly, pending, synced, failed, pendingDelete }

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

  /// Özel kategorilerde gerçek adı, eski kayıtlarda null değerini taşır.
  String? categoryName;

  late DateTime date;

  String? merchantName;

  @Enumerated(EnumType.name)
  late TransactionSource source;

  /// Cihazlar arasında işlemi tekil olarak tanımlayan UUID.
  @Index()
  String? clientRecordId;

  /// Kaydın yerel sahibi: `guest:installation-id` veya `user:user-id`.
  @Index()
  String? ownerKey;

  /// Kaydın bulut senkronizasyonundaki güncel durumu.
  @Enumerated(EnumType.name)
  SyncState syncState = SyncState.localOnly;

  /// Ham OCR metni — kullanıcı gizlilik ayarından kapatılabilir.
  String? rawOcrText;

  String? note;

  late DateTime createdAt;
  late DateTime updatedAt;

  /// Repository tarafından ayrı Isar koleksiyonuna yazılan fiş satırları.
  @ignore
  List<ReceiptLineItemEntity> receiptLineItems = [];

  /// Boş listenin gerçekten boş mu, yoksa henüz yüklenmemiş mi olduğunu ayırır.
  @ignore
  bool receiptLineItemsLoaded = false;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transactionType': transactionType.name,
      'amountInMinor': amountInMinor,
      'category': category.name,
      'categoryName': categoryName,
      'date': date.toIso8601String(),
      'merchantName': merchantName,
      'source': source.name,
      'clientRecordId': clientRecordId,
      'ownerKey': ownerKey,
      'syncState': syncState.name,
      'rawOcrText': rawOcrText,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (receiptLineItemsLoaded)
        'receiptItems': receiptLineItems.map((item) => item.toJson()).toList(),
    };
  }
}
