import 'package:finance_database/finance_database.dart';
import 'package:isar/isar.dart';

import '../data/group_offline_operation_mapper.dart';
import '../domain/group_offline_operation.dart';

/// GroupExpense create/update snapshot'ını yerel Isar veritabanına yazar.
///
/// Oturum açmış kullanıcıda masraf ve OfflineTask tek transaction'da kalıcı
/// olur. Guest kapsamı yalnız yerelde tutulur ve hiçbir zaman grup sync
/// kuyruğuna eklenmez.
class OfflineFirstGroupExpenseWriter {
  const OfflineFirstGroupExpenseWriter(
    this._repository, {
    this._triggerSynchronization,
  });

  final GroupExpenseOfflineRepository _repository;
  final void Function()? _triggerSynchronization;

  Future<Id> save(GroupExpenseOfflineOperation operation) async {
    if (operation.type == GroupOfflineOperationType.groupExpenseDelete) {
      throw UnsupportedError(
        'GroupExpense delete yerel tombstone akışı Task 6.4 kapsamında '
        'ayrı bir metotla ele alınmalıdır.',
      );
    }

    final entity = operation.toGroupExpenseEntity();

    if (operation.ownerKey.startsWith('guest:')) {
      entity.syncState = SyncState.localOnly;
      return _repository.saveLocalOnly(entity);
    }

    if (operation.syncState != SyncState.pending) {
      throw StateError(
        'Yeni grup masrafı kuyruğa pending durumda eklenmelidir.',
      );
    }

    final id = await _repository.savePendingWithOfflineTask(
      entity,
      operation.toOfflineTask(),
    );
    _triggerSynchronization?.call();
    return id;
  }

  Future<Id> saveSettlement(SettlementOfflineOperation operation) async {
    if (!operation.ownerKey.startsWith('user:')) {
      throw StateError('Settlement için aktif kullanıcı oturumu gerekli.');
    }
    if (operation.syncState != SyncState.pending) {
      throw StateError('Yeni settlement pending durumda olmalıdır.');
    }
    final id = await _repository.enqueueGroupTask(
      operation.toOfflineTask(),
      ownerKey: operation.ownerKey,
    );
    _triggerSynchronization?.call();
    return id;
  }
}
