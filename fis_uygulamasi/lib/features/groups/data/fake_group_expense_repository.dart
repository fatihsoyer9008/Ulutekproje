import '../domain/group_models.dart';
import 'group_repository.dart';

/// Expense-specific fake that keeps expense screens independent from the
/// combined group repository implementation.
class FakeGroupExpenseRepository implements GroupExpenseRepository {
  const FakeGroupExpenseRepository(this._delegate);

  final GroupExpenseRepository _delegate;

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) {
    return _delegate.listExpenses(groupId);
  }

  @override
  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  }) {
    return _delegate.getExpense(groupId: groupId, expenseId: expenseId);
  }

  @override
  Future<GroupExpense> createExpense(
    GroupExpense expense, {
    required String idempotencyKey,
  }) {
    return _delegate.createExpense(expense, idempotencyKey: idempotencyKey);
  }
}
