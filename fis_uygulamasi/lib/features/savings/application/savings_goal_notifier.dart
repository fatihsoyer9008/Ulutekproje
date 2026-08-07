import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';

final savingsGoalProvider =
    StateNotifierProvider<
      SavingsGoalNotifier,
      AsyncValue<List<SavingsGoalEntity>>
    >((ref) {
      return SavingsGoalNotifier(ref.watch(savingsGoalRepositoryProvider));
    });

class SavingsGoalNotifier
    extends StateNotifier<AsyncValue<List<SavingsGoalEntity>>> {
  SavingsGoalNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadGoals();
  }

  final SavingsGoalRepository _repository;

  Future<void> loadGoals() async {
    state = await AsyncValue.guard(_repository.getGoals);
  }

  Future<void> addGoal(SavingsGoalEntity goal) async {
    await _repository.addGoal(goal);
    await loadGoals();
  }

  Future<void> updateGoalAmount(int id, double amount) async {
    await _repository.updateGoalAmount(id, amount);
    await loadGoals();
  }

  Future<void> deleteGoal(int id) async {
    await _repository.deleteGoal(id);
    await loadGoals();
  }
}
