import 'dart:convert';
import 'dart:math';

import 'package:app_main/features/sync/application/offline_first_transaction_writer.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('giriş yapan kullanıcının kaydından sonra sync tetikler', () async {
    TransactionEntity? savedTransaction;
    OfflineTask? savedTask;
    var localSaveCount = 0;
    var syncTriggerCount = 0;

    final writer = OfflineFirstTransactionWriter(
      saveTransaction: (_) async => localSaveCount++,
      saveTransactionWithOfflineTask: (transaction, buildTask) async {
        final now = DateTime.utc(2026, 8, 5, 10);
        transaction
          ..createdAt = now
          ..updatedAt = now;
        savedTransaction = transaction;
        savedTask = buildTask(transaction);
      },
      triggerSynchronization: () => syncTriggerCount++,
      random: Random(7),
    );
    final transaction = _transaction();

    await writer.save(transaction, authenticatedUserId: 'user-id');

    expect(localSaveCount, 0);
    expect(syncTriggerCount, 1);
    expect(savedTransaction, same(transaction));
    expect(transaction.ownerKey, 'user:user-id');
    expect(transaction.syncState, SyncState.pending);
    expect(
      transaction.clientRecordId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(savedTask, isNotNull);
    expect(savedTask!.type, OfflineTaskType.createTransaction);

    final payload = jsonDecode(savedTask!.payloadJson) as Map<String, dynamic>;

    expect(payload['client_record_id'], transaction.clientRecordId);
    expect(payload['transaction_type'], 'expense');
    expect(payload['amount_in_minor'], 2500);
    expect(payload['category'], 'market');
    expect(payload['client_created_at'], '2026-08-05T10:00:00.000Z');
  });

  test('misafir kaydı sync kuyruğuna eklenmez ve sync tetiklemez', () async {
    var localSaveCount = 0;
    var atomicSaveCount = 0;
    var syncTriggerCount = 0;

    final writer = OfflineFirstTransactionWriter(
      saveTransaction: (_) async => localSaveCount++,
      saveTransactionWithOfflineTask: (_, _) async => atomicSaveCount++,
      triggerSynchronization: () => syncTriggerCount++,
      random: Random(7),
    );
    final transaction = _transaction();

    await writer.save(transaction, authenticatedUserId: null);

    expect(localSaveCount, 1);
    expect(atomicSaveCount, 0);
    expect(syncTriggerCount, 0);
    expect(transaction.syncState, SyncState.localOnly);
    expect(transaction.clientRecordId, isNull);
  });

  test('atomik kayıt başarısız olursa sync tetiklenmez', () async {
    var syncTriggerCount = 0;

    final writer = OfflineFirstTransactionWriter(
      saveTransaction: (_) async {},
      saveTransactionWithOfflineTask: (_, _) async {
        throw StateError('atomic write failed');
      },
      triggerSynchronization: () => syncTriggerCount++,
      random: Random(7),
    );

    await expectLater(
      writer.save(_transaction(), authenticatedUserId: 'user-id'),
      throwsA(isA<StateError>()),
    );

    expect(syncTriggerCount, 0);
  });

  test(
    'sync scheduler hatası kalıcı yerel kaydı başarısız göstermez',
    () async {
      var atomicSaveCount = 0;

      final writer = OfflineFirstTransactionWriter(
        saveTransaction: (_) async {},
        saveTransactionWithOfflineTask: (_, _) async {
          atomicSaveCount++;
        },
        triggerSynchronization: () {
          throw StateError('scheduler unavailable');
        },
        random: Random(7),
      );

      await writer.save(_transaction(), authenticatedUserId: 'user-id');

      expect(atomicSaveCount, 1);
    },
  );
}

TransactionEntity _transaction() => TransactionEntity()
  ..transactionType = TransactionType.expense
  ..amountInMinor = 2500
  ..category = TransactionCategory.market
  ..date = DateTime.utc(2026, 8, 5)
  ..merchantName = 'Market'
  ..source = TransactionSource.manual;
