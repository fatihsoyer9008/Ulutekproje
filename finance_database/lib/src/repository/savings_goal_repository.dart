import 'package:isar/isar.dart';

import '../models/savings_goal_entity.dart';

class SavingsGoalRepository {
  SavingsGoalRepository(this._isar);

  final Isar _isar;

  Future<Id> addGoal(SavingsGoalEntity goal) {
    return _isar.writeTxn(() => _isar.savingsGoalEntitys.put(goal));
  }

  Future<List<SavingsGoalEntity>> getGoals() async {
    final goals = await _isar.savingsGoalEntitys.where().findAll();
    goals.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return goals;
  }

  Future<void> updateGoalAmount(Id id, double amount) async {
    if (amount < 0) {
      throw ArgumentError.value(amount, 'amount', 'Tutar negatif olamaz.');
    }
    await _isar.writeTxn(() async {
      final goal = await _isar.savingsGoalEntitys.get(id);
      if (goal == null) throw StateError('Birikim hedefi bulunamadı.');
      goal.currentAmount = amount;
      await _isar.savingsGoalEntitys.put(goal);
    });
  }

  Future<void> deleteGoal(Id id) {
    return _isar.writeTxn(() async {
      await _isar.savingsGoalEntitys.delete(id);
    });
  }
}
