import 'package:isar/isar.dart';

import '../models/receipt_entity.dart';
import '../models/receipt_line_item_entity.dart';
import '../models/transaction_draft.dart';
import '../models/transaction_entity.dart';

class ReceiptRepository {
  ReceiptRepository(this._isar);

  final Isar _isar;

  Future<Id> addReceipt(
    ReceiptEntity receipt,
    List<ReceiptLineItemEntity> lineItems,
  ) async {
    final now = DateTime.now();
    receipt.createdAt = now;
    receipt.updatedAt = now;

    return _isar.writeTxn(() async {
      final receiptId = await _isar.receiptEntitys.put(receipt);
      for (final item in lineItems) {
        item
          ..receiptId = receiptId
          ..createdAt = now
          ..updatedAt = now;
      }
      if (lineItems.isNotEmpty) {
        await _isar.receiptLineItemEntitys.putAll(lineItems);
      }
      return receiptId;
    });
  }

  Future<Id> addDraft(TransactionDraft draft, {int? transactionId}) {
    final (receipt, items) = _entitiesFromDraft(draft);
    receipt.transactionId = transactionId;
    return addReceipt(receipt, items);
  }

  /// Finans işlemini, fişi ve ürün kalemlerini tek Isar transaction'ında saklar.
  Future<Id> saveReceiptTransaction({
    required TransactionEntity transaction,
    required ReceiptEntity receipt,
    required List<ReceiptLineItemEntity> lineItems,
  }) async {
    final now = DateTime.now();

    return _isar.writeTxn(() async {
      transaction
        ..createdAt = now
        ..updatedAt = now;
      final transactionId = await _isar.transactionEntitys.put(transaction);

      receipt
        ..transactionId = transactionId
        ..createdAt = now
        ..updatedAt = now;
      final receiptId = await _isar.receiptEntitys.put(receipt);

      for (final item in lineItems) {
        item
          ..receiptId = receiptId
          ..createdAt = now
          ..updatedAt = now;
      }
      if (lineItems.isNotEmpty) {
        await _isar.receiptLineItemEntitys.putAll(lineItems);
      }
      return transactionId;
    });
  }

  Future<Id> saveDraftTransaction(
    TransactionEntity transaction,
    TransactionDraft draft,
  ) {
    final (receipt, items) = _entitiesFromDraft(draft);
    return saveReceiptTransaction(
      transaction: transaction,
      receipt: receipt,
      lineItems: items,
    );
  }

  Future<ReceiptEntity?> getReceipt(Id id) => _isar.receiptEntitys.get(id);

  Future<List<ReceiptLineItemEntity>> getLineItems(Id receiptId) => _isar
      .receiptLineItemEntitys
      .filter()
      .receiptIdEqualTo(receiptId)
      .findAll();

  Future<void> deleteReceipt(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.receiptLineItemEntitys
          .filter()
          .receiptIdEqualTo(id)
          .deleteAll();
      await _isar.receiptEntitys.delete(id);
    });
  }
}

(ReceiptEntity, List<ReceiptLineItemEntity>) _entitiesFromDraft(
  TransactionDraft draft,
) {
  final receipt = ReceiptEntity()
    ..merchantName = _nullIfBlank(draft.institutionName)
    ..totalAmountInMinor = draft.amountInMinor ?? 0
    ..date = draft.transactionDate
    ..category = _nullIfBlank(draft.category)
    ..rawOcrText = _nullIfBlank(draft.rawOcrText);
  final items = draft.lineItems
      .map(
        (item) => ReceiptLineItemEntity()
          ..name = item.name.trim()
          ..totalAmountInMinor = item.totalAmountInMinor
          ..quantityInMillis = item.quantityInMillis
          ..unitPriceInMinor = item.unitPriceInMinor
          ..taxRateInBasisPoints = item.taxRateInBasisPoints
          ..category = _nullIfBlank(item.category),
      )
      .toList();
  return (receipt, items);
}

String? _nullIfBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
