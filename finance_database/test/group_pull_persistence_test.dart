import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late GroupExpenseOfflineRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'group_pull_persistence_test_',
    );
    isar = await Isar.open(
      [ExpenseShareEntitySchema, GroupSettlementEntitySchema],
      directory: tempDirectory.path,
      name: 'group_pull_persistence_test',
    );
    repository = GroupExpenseOfflineRepository(isar);
  });

  setUp(() => isar.writeTxn(isar.clear));

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('ExpenseShare pull snapshotı idempotent saklanır', () async {
    final snapshot = _share(serverUpdatedAt: DateTime.utc(2026, 8, 18, 10));

    expect(await repository.saveExpenseShareFromPull(snapshot), isTrue);
    expect(
      await repository.saveExpenseShareFromPull(
        _share(serverUpdatedAt: DateTime.utc(2026, 8, 18, 10)),
      ),
      isFalse,
    );

    expect(await isar.expenseShareEntitys.count(), 1);
    final stored = await repository.getExpenseShare(
      expenseId: expenseId,
      userId: shareUserId,
      ownerKey: ownerA,
    );
    expect(stored?.amountInMinor, 4500);
    expect(stored?.deletedAt, isNull);
  });

  test(
    'ExpenseShare tombstone eski snapshotın geri gelmesini engeller',
    () async {
      final deletedAt = DateTime.utc(2026, 8, 18, 12);

      expect(
        await repository.applyExpenseShareTombstoneFromPull(
          expenseId: expenseId,
          userId: shareUserId,
          groupId: groupId,
          ownerKey: ownerA,
          deletedAt: deletedAt,
        ),
        isTrue,
      );
      expect(
        await repository.saveExpenseShareFromPull(
          _share(serverUpdatedAt: DateTime.utc(2026, 8, 18, 11)),
        ),
        isFalse,
      );

      final stored = await repository.getExpenseShare(
        expenseId: expenseId,
        userId: shareUserId,
        ownerKey: ownerA,
      );
    expect(stored?.deletedAt?.toUtc(), deletedAt);
      expect(
        await repository.getActiveExpenseShares(
          expenseId: expenseId,
          ownerKey: ownerA,
        ),
        isEmpty,
      );
    },
  );

  test('aynı ExpenseShare farklı kullanıcı kapsamlarında ayrılır', () async {
    await repository.saveExpenseShareFromPull(
      _share(serverUpdatedAt: DateTime.utc(2026, 8, 18, 10)),
    );
    await repository.saveExpenseShareFromPull(
      _share(ownerKey: ownerB, serverUpdatedAt: DateTime.utc(2026, 8, 18, 10)),
    );

    expect(await isar.expenseShareEntitys.count(), 2);
    expect(
      await repository.getExpenseShare(
        expenseId: expenseId,
        userId: shareUserId,
        ownerKey: ownerB,
      ),
      isNotNull,
    );
  });

  test(
    'Settlement pull snapshotı idempotent ve owner scoped saklanır',
    () async {
      final serverUpdatedAt = DateTime.utc(2026, 8, 18, 10);

      expect(
        await repository.saveSettlementFromPull(
          _settlement(serverUpdatedAt: serverUpdatedAt),
        ),
        isTrue,
      );
      expect(
        await repository.saveSettlementFromPull(
          _settlement(serverUpdatedAt: serverUpdatedAt),
        ),
        isFalse,
      );
      expect(
        await repository.saveSettlementFromPull(
          _settlement(ownerKey: ownerB, serverUpdatedAt: serverUpdatedAt),
        ),
        isTrue,
      );

      expect(await isar.groupSettlementEntitys.count(), 2);
      final ownerASettlements = await repository.getSettlementsByGroup(
        groupId: groupId,
        ownerKey: ownerA,
      );
      expect(ownerASettlements, hasLength(1));
      expect(ownerASettlements.single.amountInMinor, 4500);
    },
  );
}

const ownerA = 'user:10000000-0000-4000-8000-000000000001';
const ownerB = 'user:10000000-0000-4000-8000-000000000002';
const groupId = '20000000-0000-4000-8000-000000000001';
const expenseId = '30000000-0000-4000-8000-000000000001';
const shareUserId = '40000000-0000-4000-8000-000000000001';
const settlementId = '50000000-0000-4000-8000-000000000001';

ExpenseShareEntity _share({
  String ownerKey = ownerA,
  required DateTime serverUpdatedAt,
}) => ExpenseShareEntity()
  ..recordKey = '$ownerKey|$expenseId|$shareUserId'
  ..expenseId = expenseId
  ..userId = shareUserId
  ..groupId = groupId
  ..ownerKey = ownerKey
  ..displayName = 'Ada'
  ..amountInMinor = 4500
  ..status = 'open'
  ..payloadJson =
      '{"expense_id":"$expenseId","user_id":"$shareUserId",'
      '"display_name":"Ada","amount_in_minor":4500,'
      '"status":"open","settled_at":null}'
  ..serverUpdatedAt = serverUpdatedAt;

GroupSettlementEntity _settlement({
  String ownerKey = ownerA,
  required DateTime serverUpdatedAt,
}) => GroupSettlementEntity()
  ..recordKey = '$ownerKey|$settlementId'
  ..settlementId = settlementId
  ..groupId = groupId
  ..ownerKey = ownerKey
  ..fromUserId = shareUserId
  ..toUserId = '40000000-0000-4000-8000-000000000002'
  ..amountInMinor = 4500
  ..currency = 'TRY'
  ..settledAt = DateTime.utc(2026, 8, 18, 9)
  ..createdAt = DateTime.utc(2026, 8, 18, 9, 1)
  ..payloadJson =
      '{"id":"$settlementId","group_id":"$groupId",'
      '"from_user_id":"$shareUserId",'
      '"to_user_id":"40000000-0000-4000-8000-000000000002",'
      '"amount_in_minor":4500,"currency":"TRY",'
      '"settled_at":"2026-08-18T09:00:00Z","note":null,'
      '"created_at":"2026-08-18T09:01:00Z"}'
  ..serverUpdatedAt = serverUpdatedAt;
