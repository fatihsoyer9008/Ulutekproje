import 'package:app_main/features/groups/domain/group_offline_operation.dart';
import 'package:finance_database/finance_database.dart';

import 'group_fixtures.dart';

const groupOperationOwnerKey = 'user:$currentUserId';

final groupExpenseCreateOperation = GroupExpenseOfflineOperation.create(
  expense: fastSplitTransferExpense,
  clientRecordId: '61000000-0000-4000-8000-000000000001',
  ownerKey: groupOperationOwnerKey,
);

final groupExpenseUpdateOperation = GroupExpenseOfflineOperation.update(
  expense: itemizedMarketExpense,
  clientRecordId: '61000000-0000-4000-8000-000000000002',
  ownerKey: groupOperationOwnerKey,
  syncState: SyncState.failed,
);

final groupExpenseDeleteOperation = GroupExpenseOfflineOperation.delete(
  groupId: twoMemberGroupId,
  expenseId: fastSplitTransferExpense.id,
  clientRecordId: '61000000-0000-4000-8000-000000000003',
  ownerKey: groupOperationOwnerKey,
);

final expenseShareCreateOperation = ExpenseShareOfflineOperation.create(
  groupId: twoMemberGroupId,
  share: fastSplitTransferExpense.shares.first,
  clientRecordId: '62000000-0000-4000-8000-000000000001',
  ownerKey: groupOperationOwnerKey,
);

final expenseShareUpdateOperation = ExpenseShareOfflineOperation.update(
  groupId: twoMemberGroupId,
  share: fastSplitTransferExpense.shares.last,
  clientRecordId: '62000000-0000-4000-8000-000000000002',
  ownerKey: groupOperationOwnerKey,
  syncState: SyncState.failed,
);

final expenseShareDeleteOperation = ExpenseShareOfflineOperation.delete(
  groupId: twoMemberGroupId,
  expenseId: fastSplitTransferExpense.id,
  userId: secondUserId,
  clientRecordId: '62000000-0000-4000-8000-000000000003',
  ownerKey: groupOperationOwnerKey,
);

final settlementCreateOperation = SettlementOfflineOperation.create(
  settlement: sampleSettlement,
  clientRecordId: '63000000-0000-4000-8000-000000000001',
  ownerKey: groupOperationOwnerKey,
);

final List<GroupOfflineOperation> allGroupOfflineOperationFixtures =
    List<GroupOfflineOperation>.unmodifiable(<GroupOfflineOperation>[
      groupExpenseCreateOperation,
      groupExpenseUpdateOperation,
      groupExpenseDeleteOperation,
      expenseShareCreateOperation,
      expenseShareUpdateOperation,
      expenseShareDeleteOperation,
      settlementCreateOperation,
    ]);

final List<Map<String, Object?>> allGroupOfflineOperationJsonFixtures =
    List<Map<String, Object?>>.unmodifiable(
      allGroupOfflineOperationFixtures.map((operation) => operation.toJson()),
    );
