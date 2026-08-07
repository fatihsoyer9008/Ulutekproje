import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:finance_database/finance_database.dart';

class LocalTransactionClaimService {
  LocalTransactionClaimService(this._repository, {Random? random})
    : _random = random ?? Random.secure();

  final TransactionRepository _repository;
  final Random _random;

  Future<int> countClaimable() => _repository.countLocalOnlyTransactions();

  Future<int> claimForUser(String userId) {
    return _repository.enqueueLocalOnlyTransactions(
      ownerKey: 'user:$userId',
      createClientRecordId: _uuidV4,
      buildOfflineTask: (transaction) => OfflineTask()
        ..clientTaskId = 'op-${_uuidV4()}'
        ..type = OfflineTaskType.createTransaction
        ..payloadJson = jsonEncode(_syncPayload(transaction)),
    );
  }

  Map<String, Object?> _syncPayload(TransactionEntity transaction) => {
    'client_record_id': transaction.clientRecordId,
    'transaction_type': transaction.transactionType.name,
    'amount_in_minor': transaction.amountInMinor,
    'category': transaction.categoryName ?? transaction.category.name,
    'transaction_date': transaction.date.toUtc().toIso8601String(),
    'merchant_name': transaction.merchantName,
    'source': transaction.source.name,
    'raw_ocr_text': transaction.rawOcrText,
    'note': transaction.note,
    'client_created_at': transaction.createdAt.toUtc().toIso8601String(),
    'client_updated_at': transaction.updatedAt.toUtc().toIso8601String(),
  };

  String _uuidV4() {
    final bytes = Uint8List.fromList(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
