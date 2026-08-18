import 'package:finance_database/finance_database.dart';

import '../domain/group_models.dart';
import '../domain/group_offline_operation.dart';
import 'offline_first_group_expense_writer.dart';

class OfflineFirstGroupExpenseMutator {
  OfflineFirstGroupExpenseMutator(
    this._repository,
    this._writer, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final GroupExpenseOfflineRepository _repository;
  final OfflineFirstGroupExpenseWriter _writer;
  final DateTime Function() _clock;

  Future<GroupExpense> updateMetadata({
    required GroupExpense expense,
    required String ownerKey,
    required String clientRecordId,
    required String title,
    required String? note,
  }) async {
    await _requireSynced(expense, ownerKey);
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty || normalizedTitle.length > 255) {
      throw StateError('Masraf başlığı 1-255 karakter olmalıdır.');
    }
    final normalizedNote = note?.trim();
    if (normalizedNote != null && normalizedNote.length > 1000) {
      throw StateError('Masraf notu en fazla 1000 karakter olmalıdır.');
    }
    final updated = GroupExpense.fromJson(<String, Object?>{
      ...expense.toJson(),
      'title': normalizedTitle,
      'note': normalizedNote?.isEmpty == true ? null : normalizedNote,
      'updated_at': _clock().toUtc().toIso8601String(),
    });
    await _writer.save(
      GroupExpenseOfflineOperation.update(
        expense: updated,
        clientRecordId: clientRecordId,
        ownerKey: ownerKey,
        expectedUpdatedAt: expense.updatedAt,
      ),
    );
    return updated;
  }

  Future<void> delete({
    required GroupExpense expense,
    required String ownerKey,
    required String clientRecordId,
  }) async {
    await _requireSynced(expense, ownerKey);
    if (expense.isFinanciallyLocked) {
      throw StateError('Borç kapatma sonrasında finansal masraf silinemez.');
    }
    await _writer.save(
      GroupExpenseOfflineOperation.delete(
        groupId: expense.groupId,
        expenseId: expense.id,
        clientRecordId: clientRecordId,
        ownerKey: ownerKey,
        expectedUpdatedAt: expense.updatedAt,
      ),
    );
  }

  Future<void> _requireSynced(GroupExpense expense, String ownerKey) async {
    if (!ownerKey.startsWith('user:')) {
      throw StateError('Masraf değişikliği için kullanıcı oturumu gerekli.');
    }
    final local = await _repository.getByExpenseId(expense.id);
    if (local == null ||
        local.groupId != expense.groupId ||
        local.ownerKey != ownerKey) {
      throw StateError('Masraf yerel kullanıcı kapsamında bulunamadı.');
    }
    if (local.syncState != SyncState.synced) {
      throw StateError(
        'Masraf güncellenmeden önce ilk senkronizasyon tamamlanmalıdır.',
      );
    }
  }
}
