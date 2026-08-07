import 'package:app_main/core/database/database_providers.dart';
import 'package:app_main/features/savings/application/savings_goal_notifier.dart';
import 'package:app_main/src/screens/savings_screen.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  testWidgets('oluşturma bottom sheet hedefi kuruş değerleriyle kaydeder', (
    tester,
  ) async {
    final store = _MemorySavingsGoalStore();
    await _pumpLiveScreen(tester, store);

    await tester.tap(find.byKey(const Key('create_first_savings_goal')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('savings_goal_title')),
      'Yeni Araba',
    );
    await tester.enterText(
      find.byKey(const Key('savings_goal_target_amount')),
      '12.000,50',
    );
    await tester.enterText(
      find.byKey(const Key('savings_goal_initial_amount')),
      '100,40',
    );
    await tester.ensureVisible(find.byKey(const Key('save_savings_goal')));
    await tester.tap(find.byKey(const Key('save_savings_goal')));
    await tester.pumpAndSettle();

    expect(store.goals.single.title, 'Yeni Araba');
    expect(store.goals.single.targetAmountInMinor, 1200050);
    expect(store.goals.single.currentAmountInMinor, 10040);
    expect(store.goals.single.ownerKey, 'user:a');
  });

  testWidgets('başlangıç tutarının hedefi aşmasını engeller', (tester) async {
    final store = _MemorySavingsGoalStore();
    await _pumpLiveScreen(tester, store);
    await tester.tap(find.byKey(const Key('create_first_savings_goal')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('savings_goal_title')), 'Test');
    await tester.enterText(
      find.byKey(const Key('savings_goal_target_amount')),
      '100,00',
    );
    await tester.enterText(
      find.byKey(const Key('savings_goal_initial_amount')),
      '100,01',
    );
    await tester.ensureVisible(find.byKey(const Key('save_savings_goal')));
    await tester.tap(find.byKey(const Key('save_savings_goal')));
    await tester.pump();

    expect(find.text('Başlangıç tutarı hedefi aşamaz.'), findsOneWidget);
    expect(store.goals, isEmpty);
  });

  testWidgets('tekrarlanan ondalıklı katkıları tam kuruşla toplar', (
    tester,
  ) async {
    final store = _MemorySavingsGoalStore()
      ..goals.add(
        SavingsGoalEntity()
          ..id = 1
          ..title = 'Kuruş Hedefi'
          ..targetAmountInMinor = 10000
          ..createdAt = DateTime(2026, 8, 7)
          ..ownerKey = 'user:a',
      );
    await _pumpLiveScreen(tester, store);

    Future<void> add(String amount) async {
      await tester.tap(find.byKey(const Key('add_money_1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('add_savings_amount_field')),
        amount,
      );
      await tester.tap(find.byKey(const Key('confirm_add_savings_amount')));
      await tester.pumpAndSettle();
    }

    await add('0,10');
    await add('0,20');
    expect(store.goals.single.currentAmountInMinor, 30);
  });
}

Future<void> _pumpLiveScreen(
  WidgetTester tester,
  _MemorySavingsGoalStore store,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeSavingsOwnerKeyProvider.overrideWith((ref) async => 'user:a'),
        savingsGoalRepositoryProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: Scaffold(body: SavingsScreen.live())),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemorySavingsGoalStore implements SavingsGoalStore {
  final goals = <SavingsGoalEntity>[];

  @override
  Future<Id> addGoal(SavingsGoalEntity goal, {required String ownerKey}) async {
    goal.id = goals.length + 1;
    goal.ownerKey = ownerKey;
    goals.add(goal);
    return goal.id;
  }

  @override
  Future<List<SavingsGoalEntity>> getGoals({required String ownerKey}) async =>
      goals.where((goal) => goal.ownerKey == ownerKey).toList();

  @override
  Future<void> updateGoalAmount(
    Id id,
    int amountInMinor, {
    required String ownerKey,
  }) async {
    final goal = goals.singleWhere(
      (goal) => goal.id == id && goal.ownerKey == ownerKey,
    );
    goal.currentAmountInMinor = amountInMinor;
  }

  @override
  Future<void> deleteGoal(Id id, {required String ownerKey}) async {
    goals.removeWhere((goal) => goal.id == id && goal.ownerKey == ownerKey);
  }
}
