import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory directory;
  late Isar isar;
  late SavingsGoalRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('savings_goal_test_');
    isar = await Isar.open(
      [SavingsGoalEntitySchema],
      directory: directory.path,
      name: 'savings_goal_test',
    );
    repository = SavingsGoalRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('hedef ekler, tutarı günceller ve siler', () async {
    final goal = SavingsGoalEntity()
      ..title = 'Yeni Araba'
      ..description = 'Hayalimdeki araba'
      ..targetAmount = 500000
      ..createdAt = DateTime(2026, 8, 7);

    final id = await repository.addGoal(goal);
    expect((await repository.getGoals()).single.title, 'Yeni Araba');

    await repository.updateGoalAmount(id, 150000);
    expect((await repository.getGoals()).single.currentAmount, 150000);

    await repository.deleteGoal(id);
    expect(await repository.getGoals(), isEmpty);
  });
}
