import '../models/transaction_draft.dart';
import '../models/transaction_entity.dart';
import '../models/receipt_line_item_entity.dart';

/// UI/OCR taslaklarını Isar varlıklarına ve Isar varlıklarını taslaklara
/// dönüştürür.
class TransactionDraftMapper {
  const TransactionDraftMapper._();

  static TransactionEntity toEntity(
    TransactionDraft draft, {
    TransactionSource source = TransactionSource.manual,
    TransactionType transactionType = TransactionType.expense,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rawOcrText,
    String? note,
  }) {
    final now = DateTime.now();
    final effectiveCreatedAt = createdAt ?? now;

    final entity = TransactionEntity()
      ..transactionType = transactionType
      ..amountInMinor = _safeAmountInMinor(draft.amountInMinor)
      ..category = _categoryFromDraft(draft.category)
      ..categoryName = _nullIfBlank(draft.category)
      ..date = date ?? draft.transactionDate ?? now
      ..merchantName = _nullIfBlank(draft.institutionName)
      ..source = source
      ..rawOcrText = _nullIfBlank(rawOcrText ?? draft.rawOcrText)
      ..note = _nullIfBlank(note)
      ..createdAt = effectiveCreatedAt
      ..updatedAt = updatedAt ?? effectiveCreatedAt;

    entity.receiptLineItems = [
      for (var index = 0; index < draft.receiptItems.length; index++)
        _toLineItemEntity(draft.receiptItems[index], index),
    ];
    entity.receiptLineItemsLoaded = true;
    return entity;
  }

  static TransactionDraft toDraft(TransactionEntity entity) {
    return TransactionDraft(
      institutionName: entity.merchantName?.trim() ?? '',
      category:
          _nullIfBlank(entity.categoryName) ??
          _categoryToDraft(entity.category),
      amountInMinor: _safeAmountInMinor(entity.amountInMinor),
      transactionDate: entity.date,
      rawOcrText: entity.rawOcrText,
      receiptItems: entity.receiptLineItems.map(_toReceiptItem).toList(),
    );
  }
}

ReceiptLineItemEntity _toLineItemEntity(ReceiptItem item, int position) {
  return ReceiptLineItemEntity()
    ..transactionId = 0
    ..position = position
    ..name = item.name.trim()
    ..category = _nullIfBlank(item.category)
    ..priceInMinor = item.priceMinor
    ..totalAmountInMinor = item.totalAmountInMinor
    ..quantity = item.quantity
    ..unitPriceInMinor = item.unitPriceInMinor
    ..taxRate = item.taxRate
    ..taxAmountInMinor = item.taxAmountInMinor;
}

ReceiptItem _toReceiptItem(ReceiptLineItemEntity item) => ReceiptItem(
  name: item.name,
  category: item.category,
  priceMinor: item.priceInMinor,
  totalAmountInMinor: item.totalAmountInMinor,
  quantity: item.quantity,
  unitPriceInMinor: item.unitPriceInMinor,
  taxRate: item.taxRate,
  taxAmountInMinor: item.taxAmountInMinor,
);

extension TransactionDraftEntityMapper on TransactionDraft {
  TransactionEntity toTransactionEntity({
    TransactionSource source = TransactionSource.manual,
    TransactionType transactionType = TransactionType.expense,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rawOcrText,
    String? note,
  }) => TransactionDraftMapper.toEntity(
    this,
    source: source,
    transactionType: transactionType,
    date: date,
    createdAt: createdAt,
    updatedAt: updatedAt,
    rawOcrText: rawOcrText,
    note: note,
  );
}

extension TransactionEntityDraftMapper on TransactionEntity {
  TransactionDraft toTransactionDraft() => TransactionDraftMapper.toDraft(this);
}

const _maxIsarInt = 9223372036854775807;

int _safeAmountInMinor(int? amountInMinor) {
  if (amountInMinor == null || amountInMinor <= 0) return 0;
  return amountInMinor.clamp(0, _maxIsarInt);
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

TransactionCategory _categoryFromDraft(String category) {
  switch (_normaliseCategory(category)) {
    case 'market':
    case 'marketalisverisi':
      return TransactionCategory.market;
    case 'ulasim':
    case 'tasima':
    case 'tasimacilik':
      return TransactionCategory.ulasim;
    case 'fatura':
    case 'faturalar':
      return TransactionCategory.fatura;
    case 'eglence':
      return TransactionCategory.eglence;
    case 'saglik':
      return TransactionCategory.saglik;
    case 'giyim':
      return TransactionCategory.giyim;
    default:
      return TransactionCategory.diger;
  }
}

String _normaliseCategory(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[^a-z]'), '');

String _categoryToDraft(TransactionCategory category) {
  switch (category) {
    case TransactionCategory.market:
      return 'Market';
    case TransactionCategory.ulasim:
      return 'Ulaşım';
    case TransactionCategory.fatura:
      return 'Fatura';
    case TransactionCategory.eglence:
      return 'Eğlence';
    case TransactionCategory.saglik:
      return 'Sağlık';
    case TransactionCategory.giyim:
      return 'Giyim';
    case TransactionCategory.diger:
      return 'Diğer';
  }
}
