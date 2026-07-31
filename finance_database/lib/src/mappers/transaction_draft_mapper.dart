import '../models/transaction_draft.dart';
import '../models/transaction_entity.dart';

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

    return TransactionEntity()
      ..transactionType = transactionType
      ..amountInMinor = _safeAmountInMinor(draft.amountInMinor)
      ..category = _categoryFromDraft(draft.category)
      ..categoryName = _nullIfBlank(draft.category)
      ..date = date ?? draft.transactionDate ?? now
      ..merchantName = _nullIfBlank(draft.institutionName)
      ..source = source
      ..rawOcrText = _nullIfBlank(rawOcrText)
      ..note = _nullIfBlank(note)
      ..createdAt = effectiveCreatedAt
      ..updatedAt = updatedAt ?? effectiveCreatedAt;
  }

  static TransactionDraft toDraft(TransactionEntity entity) {
    return TransactionDraft(
      institutionName: entity.merchantName?.trim() ?? '',
      category:
          _nullIfBlank(entity.categoryName) ??
          _categoryToDraft(entity.category),
      amountInMinor: _safeAmountInMinor(entity.amountInMinor),
      transactionDate: entity.date,
    );
  }
}

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
