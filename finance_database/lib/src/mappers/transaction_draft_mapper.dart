import '../models/transaction_draft.dart';
import '../models/transaction_entity.dart';

/// Converts UI/OCR drafts to database entities and back.
class TransactionDraftMapper {
  const TransactionDraftMapper._();

  static TransactionEntity toEntity(
    TransactionDraft draft, {
    TransactionSource source = TransactionSource.manual,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rawOcrText,
    String? note,
  }) {
    final now = DateTime.now();
    final effectiveCreatedAt = createdAt ?? now;

    return TransactionEntity()
      ..amountInMinor = _amountToMinor(draft.amount)
      ..category = _categoryFromDraft(draft.category)
      ..date = date ?? now
      ..merchantName = _nullIfBlank(draft.institutionName)
      ..source = source
      ..rawOcrText = _nullIfBlank(rawOcrText)
      ..note = _nullIfBlank(note)
      ..createdAt = effectiveCreatedAt
      ..updatedAt = updatedAt ?? effectiveCreatedAt;
  }

  static TransactionDraft toDraft(TransactionEntity entity) =>
      TransactionDraft(
        institutionName: entity.merchantName?.trim() ?? '',
        category: _categoryToDraft(entity.category),
        amount: entity.amountInMinor < 0 ? 0 : entity.amountInMinor / 100,
      );
}

/// Extension: Draft -> Entity
extension TransactionDraftEntityMapper on TransactionDraft {
  TransactionEntity toTransactionEntity({
    TransactionSource source = TransactionSource.manual,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rawOcrText,
    String? note,
  }) => TransactionDraftMapper.toEntity(
    this,
    source: source,
    date: date,
    createdAt: createdAt,
    updatedAt: updatedAt,
    rawOcrText: rawOcrText,
    note: note,
  );
}

/// Extension: Entity -> Draft
extension TransactionEntityDraftMapper on TransactionEntity {
  TransactionDraft toTransactionDraft() => TransactionDraftMapper.toDraft(this);
}

/// Maximum value supported by Isar Int64.
const _maxIsarInt = 9223372036854775807;

/// Converts ₺ value to kuruş.
int _amountToMinor(double? amount) {
  if (amount == null || !amount.isFinite || amount <= 0) return 0;

  final scaledAmount = amount * 100;
  if (!scaledAmount.isFinite) return _maxIsarInt;

  return scaledAmount.round().clamp(0, _maxIsarInt);
}

/// Converts blank strings to null.
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
