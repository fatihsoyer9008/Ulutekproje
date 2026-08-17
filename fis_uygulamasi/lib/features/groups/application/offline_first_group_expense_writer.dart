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
  const OfflineFirstGroupExpenseWriter(this._repository);

  final GroupExpenseOfflineRepository _repository;

  Future<Id> save(GroupExpenseOfflineOperation operation) {
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

    return _repository.savePendingWithOfflineTask(
      entity,
      operation.toOfflineTask(),
    );
  }
}
