import 'package:app_main/features/groups/domain/group_offline_operation.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';
import '../../fixtures/group_offline_operation_fixtures.dart';

void main() {
  group('GroupOfflineOperation', () {
    test('Task 6.1 kapsamındaki bütün geçerli operation türlerini sunar', () {
      expect(
        allGroupOfflineOperationFixtures.map((operation) => operation.type),
        containsAllInOrder(GroupOfflineOperationType.values),
      );
      expect(GroupOfflineOperationType.values, hasLength(7));
    });

    test('her fixture ortak offline metadata alanlarını taşır', () {
      for (final operation in allGroupOfflineOperationFixtures) {
        expect(operation.clientRecordId, isNotEmpty);
        expect(operation.ownerKey, groupOperationOwnerKey);
        expect(operation.groupId, isNotEmpty);
        expect(operation.syncState, isA<SyncState>());

        final json = operation.toJson();
        expect(json['client_record_id'], operation.clientRecordId);
        expect(json['owner_key'], operation.ownerKey);
        expect(json['sync_state'], operation.syncState.name);
      }
    });

    test('bütün operation fixtureları JSON round-trip kaybı yaşamaz', () {
      for (
        var index = 0;
        index < allGroupOfflineOperationFixtures.length;
        index++
      ) {
        final operation = allGroupOfflineOperationFixtures[index];
        final json = allGroupOfflineOperationJsonFixtures[index];
        final restored = GroupOfflineOperation.fromJson(json);

        expect(restored.runtimeType, operation.runtimeType);
        expect(restored.toJson(), json);
      }
    });

    test('GroupExpense create/update snapshot, delete yalnız kimlik taşır', () {
      expect(groupExpenseCreateOperation.expense, fastSplitTransferExpense);
      expect(groupExpenseUpdateOperation.expense, itemizedMarketExpense);
      expect(groupExpenseDeleteOperation.expense, isNull);
      expect(groupExpenseDeleteOperation.syncState, SyncState.pendingDelete);
      expect(groupExpenseDeleteOperation.payloadToJson(), <String, Object?>{
        'group_id': twoMemberGroupId,
        'expense_id': fastSplitTransferExpense.id,
      });
    });

    test(
      'ExpenseShare create/update snapshot, delete bileşik kimlik taşır',
      () {
        expect(
          expenseShareCreateOperation.share,
          fastSplitTransferExpense.shares.first,
        );
        expect(
          expenseShareUpdateOperation.share,
          fastSplitTransferExpense.shares.last,
        );
        expect(expenseShareDeleteOperation.share, isNull);
        expect(expenseShareDeleteOperation.syncState, SyncState.pendingDelete);
        expect(expenseShareDeleteOperation.payloadToJson(), <String, Object?>{
          'expense_id': fastSplitTransferExpense.id,
          'user_id': secondUserId,
        });
      },
    );

    test('Settlement yalnız immutable create operation olarak modellenir', () {
      expect(
        GroupOfflineOperationType.values.where(
          (type) => type.name.startsWith('settlement'),
        ),
        <GroupOfflineOperationType>[GroupOfflineOperationType.settlementCreate],
      );
      expect(settlementCreateOperation.settlement, sampleSettlement);
    });

    test('sync state değişimi kimlik ve payloadı korur', () {
      final retried = groupExpenseUpdateOperation.withSyncState(
        SyncState.pending,
      );

      expect(retried.syncState, SyncState.pending);
      expect(
        retried.clientRecordId,
        groupExpenseUpdateOperation.clientRecordId,
      );
      expect(retried.ownerKey, groupExpenseUpdateOperation.ownerKey);
      expect(
        retried.payloadToJson(),
        groupExpenseUpdateOperation.payloadToJson(),
      );
    });

    test('geçersiz UUID ve owner scope model oluşturulurken reddedilir', () {
      expect(
        () => GroupExpenseOfflineOperation.delete(
          groupId: twoMemberGroupId,
          expenseId: 'not-a-uuid',
          clientRecordId: '61000000-0000-4000-8000-000000000099',
          ownerKey: groupOperationOwnerKey,
        ),
        throwsArgumentError,
      );
      expect(
        () => SettlementOfflineOperation.create(
          settlement: sampleSettlement,
          clientRecordId: '63000000-0000-4000-8000-000000000099',
          ownerKey: 'unknown:$currentUserId',
        ),
        throwsArgumentError,
      );
    });

    test('bilinmeyen operation ve sync state JSON değerleri reddedilir', () {
      final validJson = groupExpenseCreateOperation.toJson();

      expect(
        () => GroupOfflineOperation.fromJson(<String, Object?>{
          ...validJson,
          'operation_type': 'settlementUpdate',
        }),
        throwsFormatException,
      );
      expect(
        () => GroupOfflineOperation.fromJson(<String, Object?>{
          ...validJson,
          'sync_state': 'unknown',
        }),
        throwsFormatException,
      );
    });

    test('zarf ve payload farklı grupları gösteriyorsa JSON reddedilir', () {
      final json = groupExpenseCreateOperation.toJson();

      expect(
        () => GroupOfflineOperation.fromJson(<String, Object?>{
          ...json,
          'group_id': fourMemberGroupId,
        }),
        throwsFormatException,
      );
    });

    test('para alanları JSON fixturelarında double olarak üretilmez', () {
      for (final operation in allGroupOfflineOperationFixtures) {
        _expectMinorAmountsAreIntegers(operation.toJson());
      }
    });
  });
}

void _expectMinorAmountsAreIntegers(Object? value) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key.toString().endsWith('amount_in_minor')) {
        expect(entry.value, isA<int>());
      }
      _expectMinorAmountsAreIntegers(entry.value);
    }
  } else if (value is Iterable) {
    for (final item in value) {
      _expectMinorAmountsAreIntegers(item);
    }
  }
}
