import '../domain/group_models.dart';
import 'group_repository.dart';

/// Debt-specific fake that can be overridden without replacing group data.
class FakeDebtSummaryRepository implements DebtSummaryRepository {
  const FakeDebtSummaryRepository(this._delegate);

  final DebtSummaryRepository _delegate;

  @override
  Future<DebtSummary> getDebtSummary(String groupId) {
    return _delegate.getDebtSummary(groupId);
  }
}
