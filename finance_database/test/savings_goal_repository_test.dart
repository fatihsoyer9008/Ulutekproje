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
      ..targetAmountInMinor = 50000000
      ..createdAt = DateTime(2026, 8, 7);

    final id = await repository.addGoal(goal, ownerKey: 'user:a');
    expect(
      (await repository.getGoals(ownerKey: 'user:a')).single.title,
      'Yeni Araba',
    );

    await repository.updateGoalAmount(id, 15000000, ownerKey: 'user:a');
    expect(
      (await repository.getGoals(
        ownerKey: 'user:a',
      )).single.currentAmountInMinor,
      15000000,
    );

    await repository.deleteGoal(id, ownerKey: 'user:a');
    expect(await repository.getGoals(ownerKey: 'user:a'), isEmpty);
  });

  test('hedefleri sahipler arasında izole eder', () async {
    Future<void> add(String title, String ownerKey) => repository.addGoal(
      SavingsGoalEntity()
        ..title = title
        ..targetAmountInMinor = 10050
        ..createdAt = DateTime(2026, 8, 7),
      ownerKey: ownerKey,
    );

    await add('A hedefi', 'user:a');
    await add('B hedefi', 'user:b');

    expect(
      (await repository.getGoals(ownerKey: 'user:a')).single.title,
      'A hedefi',
    );
    expect(
      (await repository.getGoals(ownerKey: 'user:b')).single.title,
      'B hedefi',
    );
  });

  test('ondalıklı katkıları kuruş olarak hatasız toplar', () async {
    final id = await repository.addGoal(
      SavingsGoalEntity()
        ..title = 'Kuruş hedefi'
        ..targetAmountInMinor = 10050
        ..createdAt = DateTime(2026, 8, 7),
      ownerKey: 'user:a',
    );

    await repository.updateGoalAmount(id, 10, ownerKey: 'user:a');
    await repository.updateGoalAmount(id, 10 + 20, ownerKey: 'user:a');

    expect(
      (await repository.getGoals(
        ownerKey: 'user:a',
      )).single.currentAmountInMinor,
      30,
    );
  });

  test('veritabanı yeniden açıldığında hedef kalıcıdır', () async {
    await repository.addGoal(
      SavingsGoalEntity()
        ..title = 'Kalıcı hedef'
        ..targetAmountInMinor = 250000
        ..createdAt = DateTime(2026, 8, 7),
      ownerKey: 'guest:installation-test',
    );

    await isar.close();
    isar = await Isar.open(
      [SavingsGoalEntitySchema],
      directory: directory.path,
      name: 'savings_goal_test',
    );
    repository = SavingsGoalRepository(isar);

    final goals = await repository.getGoals(
      ownerKey: 'guest:installation-test',
    );
    expect(goals.single.title, 'Kalıcı hedef');
    expect(goals.single.targetAmountInMinor, 250000);
  });
}
