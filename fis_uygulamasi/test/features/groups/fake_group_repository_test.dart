import 'dart:convert';
import 'dart:io';

import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  group('group contract models', () {
    test('preserve contract JSON names and integer minor amounts', () {
      final groupJson = twoMemberGroup.toJson();
      final expenseJson = itemizedMarketExpense.toJson();

      expect(groupJson['member_count'], 2);
      expect(groupJson, isNot(contains('memberCount')));
      expect(expenseJson['total_amount_in_minor'], isA<int>());
      expect(expenseJson, isNot(contains('totalAmountInMinor')));
      expect(
        (expenseJson['line_item_assignments']! as List<Object?>).first,
        containsPair('quantity_share_milli', 1000),
      );
    });

    test('round-trips every required fixture', () {
      expect(
        GroupDetail.fromJson(twoMemberGroup.toJson()).toJson(),
        twoMemberGroup.toJson(),
      );
      expect(
        GroupExpense.fromJson(itemizedMarketExpense.toJson()).toJson(),
        itemizedMarketExpense.toJson(),
      );
      expect(
        DebtSummary.fromJson(currentUserDebtorDebtSummary.toJson()).toJson(),
        currentUserDebtorDebtSummary.toJson(),
      );
      expect(
        Settlement.fromJson(sampleSettlement.toJson()).toJson(),
        sampleSettlement.toJson(),
      );
      expect(emptyGroupsResponse.toJson(), <String, Object?>{
        'groups': <Object?>[],
      });
    });

    test('keeps raw JSON files aligned with typed fixtures', () {
      expect(
        _readJsonFixture('docs/fixtures/groups/group.json'),
        Group.fromJson(twoMemberGroup.toJson()).toJson(),
      );
      expect(
        _readJsonFixture('docs/fixtures/groups/group_member.json'),
        twoMemberGroup.members[1].toJson(),
      );
      expect(
        _readJsonFixture('docs/fixtures/groups/group_expense.json'),
        fastSplitTransferExpense.toJson(),
      );
      expect(
        _readJsonFixture('docs/fixtures/groups/expense_share.json'),
        fastSplitTransferExpense.shares[1].toJson(),
      );
      expect(
        _readJsonFixture(
          'docs/fixtures/group_debts/debt_summary_2_members.json',
        ),
        currentUserDebtorDebtSummary.toJson(),
      );
    });

    test('exposes loading and contract-shaped API error states', () {
      expect(groupsLoading, isA<AsyncLoading<GroupsResponse>>());
      expect(groupsApiError, isA<AsyncError<GroupsResponse>>());
      expect(groupsApiErrorException.error.toJson(), <String, Object?>{
        'detail': <String, Object?>{
          'code': 'service_unavailable',
          'message': 'Grup bilgileri şu anda alınamıyor.',
          'field_errors': <Object?>[],
        },
      });
    });
  });

  group('FakeGroupRepository', () {
    test('lists only groups containing the current user', () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup, fourMemberGroup],
        currentUserId: elifnurUserId,
      );

      final response = await repository.listGroups();

      expect(response.groups.map((group) => group.id), <String>[
        fourMemberGroupId,
      ]);
    });

    test('can be replaced through the Riverpod provider', () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      );
      final container = ProviderContainer(
        overrides: <Override>[
          groupRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(groupsProvider),
        isA<AsyncLoading<GroupsResponse>>(),
      );
      final response = await container.read(groupsProvider.future);

      expect(response.groups.single.id, twoMemberGroupId);
    });

    test('overrides expense and debt repositories independently', () async {
      final expenseSource = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        expensesByGroup: const <String, List<GroupExpense>>{
          twoMemberGroupId: <GroupExpense>[fastSplitTransferExpense],
        },
      );
      final debtSource = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        debtSummariesByGroup: const <String, DebtSummary>{
          twoMemberGroupId: currentUserCreditorDebtSummary,
        },
      );
      final container = ProviderContainer(
        overrides: <Override>[
          groupExpenseRepositoryProvider.overrideWithValue(
            FakeGroupExpenseRepository(expenseSource),
          ),
          debtSummaryRepositoryProvider.overrideWithValue(
            FakeDebtSummaryRepository(debtSource),
          ),
        ],
      );
      addTearDown(container.dispose);

      final expenses = await container.read(
        groupExpensesProvider(twoMemberGroupId).future,
      );
      final debtSummary = await container.read(
        groupDebtSummaryProvider(twoMemberGroupId).future,
      );

      expect(expenses.single.toJson(), fastSplitTransferExpense.toJson());
      expect(debtSummary.toJson(), currentUserCreditorDebtSummary.toJson());
    });

    test('surfaces configured API errors through the async provider', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          groupRepositoryProvider.overrideWithValue(
            FakeGroupRepository(error: groupsApiErrorException),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(groupsProvider.future),
        throwsA(
          isA<GroupApiException>().having(
            (error) => error.code,
            'code',
            'service_unavailable',
          ),
        ),
      );
    });

    test('creates a group with the current user as owner', () async {
      final repository = FakeGroupRepository(
        currentUserDisplayName: 'Elifnur',
        clock: () => DateTime.utc(2026, 8, 10, 15),
      );

      final group = await repository.createGroup(
        name: '  Proje Ekibi  ',
        description: 'Ortak giderler',
      );

      expect(group.name, 'Proje Ekibi');
      expect(group.currentUserRole, GroupRole.owner);
      expect(group.members.single.role, GroupRole.owner);
      expect(group.createdAt, '2026-08-10T15:00:00.000Z');
    });

    test('rejects duplicate members with the contract error code', () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      );

      await expectLater(
        repository.addMember(
          groupId: twoMemberGroupId,
          userId: secondUserId,
          displayName: 'Abdullah Seydi',
        ),
        throwsA(
          isA<GroupApiException>().having(
            (error) => error.code,
            'code',
            'member_already_exists',
          ),
        ),
      );
    });

    test('rejects group updates from a member', () async {
      final repository = FakeGroupRepository(
        currentUserId: secondUserId,
        groups: const <GroupDetail>[twoMemberGroup],
      );

      await expectLater(
        repository.updateGroup(groupId: twoMemberGroupId, name: 'Yeni ad'),
        throwsA(
          isA<GroupApiException>().having(
            (error) => error.code,
            'code',
            'group_forbidden',
          ),
        ),
      );
    });

    test('returns the same expense for an idempotent retry', () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      );

      final first = await repository.createExpense(
        fastSplitTransferExpense,
        idempotencyKey: 'expense-request-1',
      );
      final retry = await repository.createExpense(
        fastSplitTransferExpense,
        idempotencyKey: 'expense-request-1',
      );

      expect(retry.toJson(), first.toJson());
      expect(await repository.listExpenses(twoMemberGroupId), hasLength(1));
    });

    test('rejects a changed body using the same idempotency key', () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      );
      await repository.createExpense(
        fastSplitTransferExpense,
        idempotencyKey: 'expense-request-2',
      );
      final changedJson = Map<String, Object?>.from(
        fastSplitTransferExpense.toJson(),
      )..['title'] = 'Değiştirilen başlık';

      await expectLater(
        repository.createExpense(
          GroupExpense.fromJson(changedJson),
          idempotencyKey: 'expense-request-2',
        ),
        throwsA(
          isA<GroupApiException>().having(
            (error) => error.code,
            'code',
            'idempotency_conflict',
          ),
        ),
      );
    });
  });
}

Map<String, Object?> _readJsonFixture(String relativePath) {
  var directory = Directory.current.absolute;
  while (true) {
    final fixture = File(
      '${directory.path}${Platform.pathSeparator}$relativePath',
    );
    if (fixture.existsSync()) {
      return Map<String, Object?>.from(
        jsonDecode(fixture.readAsStringSync()) as Map<Object?, Object?>,
      );
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      throw StateError('Repository root not found for $relativePath');
    }
    directory = parent;
  }
}
