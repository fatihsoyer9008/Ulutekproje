import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../auth/presentation/controllers/auth_session_controller.dart';
import '../../sync/application/sync_coordinator.dart';

final activeSavingsOwnerKeyProvider = FutureProvider<String>((ref) async {
  final auth = ref.watch(authSessionControllerProvider);
  final userId = auth.user?.id;
  if (auth.status == AuthStatus.authenticated && userId != null) {
    return 'user:$userId';
  }
  final installationId = await ref
      .watch(installationIdProvider)
      .getInstallationId();
  return 'guest:$installationId';
});

final savingsGoalProvider = StateNotifierProvider.autoDispose
    .family<SavingsGoalNotifier, AsyncValue<List<SavingsGoalEntity>>, String>(
      (ref, ownerKey) => SavingsGoalNotifier(
        ref.watch(savingsGoalRepositoryProvider),
        ownerKey: ownerKey,
      ),
    );

class SavingsGoalNotifier
    extends StateNotifier<AsyncValue<List<SavingsGoalEntity>>> {
  SavingsGoalNotifier(this._repository, {required this.ownerKey})
    : super(const AsyncValue.loading()) {
    loadGoals();
  }

  final SavingsGoalStore _repository;
  final String ownerKey;

  Future<void> loadGoals() async {
    state = await AsyncValue.guard(
      () => _repository.getGoals(ownerKey: ownerKey),
    );
  }

  Future<void> addGoal(SavingsGoalEntity goal) async {
    await _repository.addGoal(goal, ownerKey: ownerKey);
    await loadGoals();
  }

  Future<void> updateGoalAmount(int id, int amountInMinor) async {
    await _repository.updateGoalAmount(id, amountInMinor, ownerKey: ownerKey);
    await loadGoals();
  }

  Future<void> deleteGoal(int id) async {
    await _repository.deleteGoal(id, ownerKey: ownerKey);
    await loadGoals();
  }
}
