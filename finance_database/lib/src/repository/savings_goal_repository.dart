import 'package:isar/isar.dart';

import '../models/savings_goal_entity.dart';

abstract interface class SavingsGoalStore {
  Future<Id> addGoal(SavingsGoalEntity goal, {required String ownerKey});
  Future<List<SavingsGoalEntity>> getGoals({required String ownerKey});
  Future<void> updateGoalAmount(
    Id id,
    int amountInMinor, {
    required String ownerKey,
  });
  Future<void> deleteGoal(Id id, {required String ownerKey});
}

class SavingsGoalRepository implements SavingsGoalStore {
  SavingsGoalRepository(this._isar);

  final Isar _isar;

  @override
  Future<Id> addGoal(SavingsGoalEntity goal, {required String ownerKey}) {
    goal.ownerKey = ownerKey;
    return _isar.writeTxn(() => _isar.savingsGoalEntitys.put(goal));
  }

  @override
  Future<List<SavingsGoalEntity>> getGoals({required String ownerKey}) async {
    final goals = await _isar.savingsGoalEntitys
        .where()
        .ownerKeyEqualTo(ownerKey)
        .findAll();
    goals.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return goals;
  }

  @override
  Future<void> updateGoalAmount(
    Id id,
    int amountInMinor, {
    required String ownerKey,
  }) async {
    if (amountInMinor < 0) {
      throw ArgumentError.value(
        amountInMinor,
        'amountInMinor',
        'Tutar negatif olamaz.',
      );
    }
    await _isar.writeTxn(() async {
      final goal = await _isar.savingsGoalEntitys.get(id);
      if (goal == null || goal.ownerKey != ownerKey) {
        throw StateError('Birikim hedefi bulunamadı.');
      }
      goal.currentAmountInMinor = amountInMinor;
      await _isar.savingsGoalEntitys.put(goal);
    });
  }

  @override
  Future<void> deleteGoal(Id id, {required String ownerKey}) {
    return _isar.writeTxn(() async {
      final goal = await _isar.savingsGoalEntitys.get(id);
      if (goal == null || goal.ownerKey != ownerKey) {
        throw StateError('Birikim hedefi bulunamadı.');
      }
      await _isar.savingsGoalEntitys.delete(id);
    });
  }
}
