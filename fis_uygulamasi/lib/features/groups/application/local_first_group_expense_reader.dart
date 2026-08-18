import 'package:finance_database/finance_database.dart';

import '../data/group_offline_operation_mapper.dart';
import '../data/group_repository.dart';
import '../domain/group_models.dart';
import '../domain/group_offline_operation.dart';

/// Isar'ı görüntüleme kaynağı, API'yi ise cache yenileme kaynağı olarak kullanır.
class LocalFirstGroupExpenseReader {
  const LocalFirstGroupExpenseReader(this._local, this._remote);

  final GroupExpenseOfflineRepository _local;
  final GroupExpenseRepository _remote;

  Stream<List<GroupExpense>> watch({
    required String groupId,
    required String ownerKey,
  }) => _local
      .watchActiveByGroup(groupId: groupId, ownerKey: ownerKey)
      .map(
        (entities) => List<GroupExpense>.unmodifiable(
          entities.map((entity) => entity.toGroupExpense()),
        ),
      );

  /// Sunucudaki güncel snapshot'ları yerel cache'e yazar.
  /// Pending/failed yerel kayıtların korunması repository tarafından sağlanır.
  Future<int> refresh({
    required String groupId,
    required String ownerKey,
  }) async {
    if (!ownerKey.startsWith('user:')) {
      throw StateError('Local-first listeleme için kullanıcı oturumu gerekli.');
    }
    final remoteExpenses = await _remote.listExpenses(groupId);
    var applied = 0;
    for (final expense in remoteExpenses) {
      if (expense.groupId != groupId) {
        throw FormatException('API farklı gruba ait masraf döndürdü.');
      }
      final entity = GroupExpenseOfflineOperation.create(
        expense: expense,
        clientRecordId: expense.id,
        ownerKey: ownerKey,
        syncState: SyncState.synced,
      ).toGroupExpenseEntity();
      if (await _local.saveSyncedFromPull(entity)) applied += 1;
    }
    return applied;
  }
}
