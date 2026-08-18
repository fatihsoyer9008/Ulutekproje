import 'dart:convert';
import 'dart:io';

import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/application/offline_first_group_expense_writer.dart';
import 'package:app_main/features/groups/application/group_expense_flow_controller.dart';
import 'package:app_main/features/groups/application/fast_split_calculator.dart';
import 'package:app_main/features/groups/application/itemized_split_calculator.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/application/group_sync_coordinator.dart';
import 'package:app_main/features/groups/data/group_offline_operation_mapper.dart';
import 'package:app_main/features/groups/data/group_sync_gateway.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_offline_operation.dart';
import 'package:app_main/features/groups/domain/group_expense_draft.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/group_detail_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../fixtures/group_fixtures.dart';
import '../../fixtures/group_offline_operation_fixtures.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late OfflineFirstGroupExpenseWriter writer;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'group_offline_persistence_test_',
    );
    isar = await Isar.open(
      [GroupExpenseEntitySchema, OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'group_offline_persistence_test',
    );
    writer = OfflineFirstGroupExpenseWriter(
      GroupExpenseOfflineRepository(isar),
    );
  });

  setUp(() => isar.writeTxn(isar.clear));

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('tüm grup operasyon türleri OfflineTask ile birebir eşleşir', () {
    for (final operation in allGroupOfflineOperationFixtures) {
      final task = operation.toOfflineTask();

      expect(task.type.name, operation.type.name);
      expect(task.clientTaskId, operation.clientRecordId);
      expect(jsonDecode(task.payloadJson), operation.toJson());
    }
  });

  test(
    'oturum açmış kullanıcının masrafı ve görevi birlikte yazılır',
    () async {
      await writer.save(groupExpenseCreateOperation);

      final expenses = await isar.groupExpenseEntitys.where().findAll();
      final tasks = await isar.offlineTasks.where().findAll();
      expect(expenses, hasLength(1));
      expect(tasks, hasLength(1));
      expect(expenses.single.expenseId, fastSplitTransferExpense.id);
      expect(tasks.single.type, OfflineTaskType.groupExpenseCreate);
    },
  );

  test('guest masrafı yerelde kalır ve sync kuyruğuna girmez', () async {
    final guestOperation = GroupExpenseOfflineOperation.create(
      expense: fastSplitTransferExpense,
      clientRecordId: '85000000-0000-4000-8000-000000000001',
      ownerKey: 'guest:installation-test',
    );

    await writer.save(guestOperation);

    final expenses = await isar.groupExpenseEntitys.where().findAll();
    expect(expenses, hasLength(1));
    expect(expenses.single.ownerKey, 'guest:installation-test');
    expect(expenses.single.syncState, SyncState.localOnly);
    expect(await isar.offlineTasks.count(), 0);
  });

  test(
    'delete operasyonu tombstone ve OfflineTask olarak atomik yazılır',
    () async {
      final repository = GroupExpenseOfflineRepository(isar);
      final synced = groupExpenseCreateOperation.toGroupExpenseEntity()
        ..syncState = SyncState.synced;
      await repository.saveSyncedFromPull(synced);

      await writer.save(groupExpenseDeleteOperation);

      final expense = (await isar.groupExpenseEntitys.where().findAll()).single;
      final task = (await isar.offlineTasks.where().findAll()).single;
      expect(expense.syncState, SyncState.pendingDelete);
      expect(expense.deletedAt, isNotNull);
      expect((jsonDecode(expense.payloadJson) as Map)['deleted_at'], isNotNull);
      expect(task.type, OfflineTaskType.groupExpenseDelete);
      expect(task.status, OfflineTaskStatus.pending);
      expect(task.clientTaskId, groupExpenseDeleteOperation.clientRecordId);
    },
  );

  test(
    'pending kayıt başarıyla yazıldıktan sonra grup sync tetiklenir',
    () async {
      var syncCalls = 0;
      final triggeringWriter = OfflineFirstGroupExpenseWriter(
        GroupExpenseOfflineRepository(isar),
        triggerSynchronization: () => syncCalls += 1,
      );

      await triggeringWriter.save(groupExpenseCreateOperation);

      expect(syncCalls, 1);
      expect(await isar.offlineTasks.count(), 1);
    },
  );

  test(
    'Settlement immutable pending operasyon olarak kuyruğa yazılır',
    () async {
      await writer.saveSettlement(settlementCreateOperation);

      final task = (await isar.offlineTasks.where().findAll()).single;
      expect(task.type, OfflineTaskType.settlementCreate);
      expect(task.status, OfflineTaskStatus.pending);
      expect(task.clientTaskId, settlementCreateOperation.clientRecordId);
      expect(
        (jsonDecode(task.payloadJson) as Map)['payload']['amount_in_minor'],
        sampleSettlement.amountInMinor,
      );
    },
  );

  test(
    'offline Fast Split ve ExpenseShare DTO kayıpsız kuyruğa yazılır',
    () async {
      final controller = GroupExpenseFlowController(
        FakeGroupRepository(groups: const <GroupDetail>[twoMemberGroup]),
        offlineWriter: writer,
        ownerKey: groupOperationOwnerKey,
      );
      controller.start(
        group: twoMemberGroup,
        activeUserId: currentUserId,
        draft: _draft(),
      );
      controller.setFastSplit(
        FastSplitCalculator.percentage(
          totalAmountInMinor: 12000,
          percentageBasisPoints: const <String, int>{
            currentUserId: 3333,
            secondUserId: 6667,
          },
          memberIds: const <String>[currentUserId, secondUserId],
        ),
        percentageBasisPoints: const <String, int>{
          currentUserId: 3333,
          secondUserId: 6667,
        },
      );

      await controller.submitFastSplit(
        idempotencyKey: '86000000-0000-4000-8000-000000000001',
      );

      final task = (await isar.offlineTasks.where().findAll()).single;
      final envelope = jsonDecode(task.payloadJson)! as Map<String, dynamic>;
      final syncPayload = envelope['sync_payload']! as Map<String, dynamic>;
      final split = syncPayload['split']! as Map<String, dynamic>;
      expect(task.status, OfflineTaskStatus.pending);
      expect(task.clientTaskId, envelope['client_record_id']);
      expect(split['type'], 'percentage');
      expect((split['shares'] as List).last['percentage_basis_points'], 6667);
      expect(syncPayload['total_amount_in_minor'], 12000);
      expect(syncPayload['currency'], 'TRY');
    },
  );

  testWidgets(
    'production detay UI Fast Split kaydını doğrudan API yerine offline writer akışına iletir',
    (tester) async {
      final auth = AuthSessionController(const _OfflineUiAuthRepository());
      await auth.login('offline@example.com', 'password');
      final recordingWriter = _RecordingOfflineWriter(
        GroupExpenseOfflineRepository(isar),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionControllerProvider.overrideWith((ref) => auth),
            groupRepositoryProvider.overrideWithValue(
              _OfflineUiGroupRepository(
                FakeGroupRepository(
                  groups: const <GroupDetail>[twoMemberGroup],
                ),
              ),
            ),
            groupExpenseRepositoryProvider.overrideWithValue(
              const _DirectApiMustNotBeCalledRepository(),
            ),
            offlineFirstGroupExpenseWriterProvider.overrideWithValue(
              recordingWriter,
            ),
          ],
          child: const MaterialApp(
            home: GroupDetailPage(groupId: twoMemberGroupId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_group_expense_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('select_fast_split_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('fast_split_title')),
        'Offline UI market',
      );
      await tester.enterText(
        find.byKey(const Key('fast_split_total')),
        '120,00',
      );
      await tester.tap(find.byKey(const Key('fast_split_submit')));
      await tester.pumpAndSettle();

      final operation = recordingWriter.savedOperation;
      expect(operation, isNotNull);
      expect(operation!.type, GroupOfflineOperationType.groupExpenseCreate);
      expect(operation.expense!.title, 'Offline UI market');
      expect(operation.syncState, SyncState.pending);
      expect(operation.syncPayload, isA<Map>());
      expect(find.text('Masraf kaydedildi.'), findsOneWidget);
    },
  );

  test(
    'offline Itemized Split satır ve ek payları kayıpsız kuyruğa yazılır',
    () async {
      final controller = GroupExpenseFlowController(
        FakeGroupRepository(groups: const <GroupDetail>[twoMemberGroup]),
        offlineWriter: writer,
        ownerKey: groupOperationOwnerKey,
      );
      controller.start(
        group: twoMemberGroup,
        activeUserId: currentUserId,
        draft: _draft(),
      );
      controller.setItemizedSplit(
        receiptId: '20000000-0000-4000-8000-000000000001',
        calculation: const ItemizedSplitCalculation(
          receiptTotalInMinor: 12000,
          lineItemsTotalInMinor: 10000,
          lineItemShares: <ItemizedLineItemShare>[
            ItemizedLineItemShare(
              receiptLineItemId: '30000000-0000-4000-8000-000000000001',
              receiptLineItemPosition: null,
              userId: currentUserId,
              amountInMinor: 4000,
              quantityShareMilli: 400,
            ),
            ItemizedLineItemShare(
              receiptLineItemId: '30000000-0000-4000-8000-000000000001',
              receiptLineItemPosition: null,
              userId: secondUserId,
              amountInMinor: 6000,
              quantityShareMilli: 600,
            ),
          ],
          extraAmountShares: <ExtraAmountShare>[
            ExtraAmountShare(userId: currentUserId, amountInMinor: 2000),
          ],
          unassignedReceiptLineItemIds: <String>{},
          hasUnknownLineTotals: false,
          hasUnsyncedLineItems: false,
        ),
      );

      await controller.submitItemizedSplit(
        idempotencyKey: '86000000-0000-4000-8000-000000000002',
      );

      final task = (await isar.offlineTasks.where().findAll()).single;
      final envelope = jsonDecode(task.payloadJson)! as Map<String, dynamic>;
      final split = (envelope['sync_payload'] as Map)['split'] as Map;
      final line = (split['line_items'] as List).single as Map;
      expect(line['shares'], hasLength(2));
      expect((line['shares'] as List).last['quantity_share_milli'], 600);
      expect((split['extra_amounts'] as List).single['amount_in_minor'], 2000);
    },
  );

  test(
    'OCR Itemized Split yerel receipt draft ile OfflineTask kuyruğuna yazılır',
    () async {
      final controller = GroupExpenseFlowController(
        FakeGroupRepository(groups: const <GroupDetail>[twoMemberGroup]),
        offlineWriter: writer,
        ownerKey: groupOperationOwnerKey,
      );
      controller.start(
        group: twoMemberGroup,
        activeUserId: currentUserId,
        draft: GroupExpenseDraft(
          groupId: twoMemberGroupId,
          payerUserId: currentUserId,
          merchantName: 'OCR market',
          category: 'Market',
          totalAmountInMinor: 12000,
          expenseDate: DateTime.utc(2026, 8, 17),
          currency: 'TRY',
          rawOcrText: 'OCR RAW',
          items: const <GroupExpenseDraftItem>[
            GroupExpenseDraftItem(
              name: 'Süt',
              category: 'Market',
              quantityMilli: 1000,
              unitPriceInMinor: 12000,
              totalAmountInMinor: 12000,
              taxRateBasisPoints: 1000,
              taxAmountInMinor: 1091,
            ),
          ],
        ),
      );
      controller.setItemizedSplit(
        receiptId: null,
        calculation: const ItemizedSplitCalculation(
          receiptTotalInMinor: 12000,
          lineItemsTotalInMinor: 12000,
          lineItemShares: <ItemizedLineItemShare>[
            ItemizedLineItemShare(
              receiptLineItemId: null,
              receiptLineItemPosition: 0,
              userId: currentUserId,
              amountInMinor: 12000,
              quantityShareMilli: 1000,
            ),
          ],
          extraAmountShares: <ExtraAmountShare>[],
          unassignedReceiptLineItemIds: <String>{},
          hasUnknownLineTotals: false,
          hasUnsyncedLineItems: false,
        ),
      );

      await controller.submitItemizedSplit(
        idempotencyKey: '86000000-0000-4000-8000-000000000003',
      );

      final task = (await isar.offlineTasks.where().findAll()).single;
      final envelope = jsonDecode(task.payloadJson) as Map<String, dynamic>;
      final syncPayload = envelope['sync_payload'] as Map<String, dynamic>;
      final receiptDraft = syncPayload['receipt_draft'] as Map<String, dynamic>;
      final split = syncPayload['split'] as Map<String, dynamic>;
      expect(receiptDraft['raw_ocr_text'], 'OCR RAW');
      expect((receiptDraft['line_items'] as List).single['position'], 0);
      expect(
        (split['line_items'] as List).single['receipt_line_item_position'],
        0,
      );
      expect(controller.state.status, GroupExpenseFlowStatus.success);
    },
  );

  test(
    'pull değişikliği Isar içine synced snapshot olarak uygulanır',
    () async {
      final syncRepository = IsarGroupSyncTaskRepository(
        GroupExpenseOfflineRepository(isar),
        groupOperationOwnerKey,
      );
      final change = GroupPullChange(
        cursor: '1',
        operation: groupExpenseCreateOperation.toJson(),
        serverUpdatedAt: DateTime.utc(2026, 8, 17),
      );

      final applied = await syncRepository.applyPulledChanges([change]);

      final stored = await isar.groupExpenseEntitys.where().findFirst();
      expect(applied, 1);
      expect(stored?.syncState, SyncState.synced);
      expect(stored?.expenseId, fastSplitTransferExpense.id);
    },
  );
}

GroupExpenseDraft _draft() => GroupExpenseDraft(
  groupId: twoMemberGroupId,
  payerUserId: currentUserId,
  merchantName: 'Market',
  category: 'Market',
  totalAmountInMinor: 12000,
  expenseDate: DateTime.utc(2026, 8, 17),
  currency: 'TRY',
  rawOcrText: null,
  items: const <GroupExpenseDraftItem>[],
);

class _DirectApiMustNotBeCalledRepository implements GroupExpenseRepository {
  const _DirectApiMustNotBeCalledRepository();

  Never _unexpected() =>
      throw StateError('Production UI doğrudan group expense API çağırdı.');

  @override
  Future<GroupExpense> createExpense(
    CreateGroupExpenseRequest request, {
    required String idempotencyKey,
  }) async => _unexpected();

  @override
  Future<GroupExpense> createFastSplit(
    FastSplitExpenseRequest request, {
    required String idempotencyKey,
  }) async => _unexpected();

  @override
  Future<GroupExpense> createItemizedSplit(
    ItemizedExpenseRequest request, {
    required String idempotencyKey,
  }) async => _unexpected();

  @override
  Future<GroupExpense> getExpense({
    required String groupId,
    required String expenseId,
  }) async => _unexpected();

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) async =>
      _unexpected();
}

class _OfflineUiGroupRepository implements GroupRepository {
  const _OfflineUiGroupRepository(this._delegate);

  final FakeGroupRepository _delegate;

  @override
  GroupRepositoryCapabilities get capabilities => _delegate.capabilities;

  @override
  Future<GroupDetail> getGroup(String groupId) => _delegate.getGroup(groupId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingOfflineWriter extends OfflineFirstGroupExpenseWriter {
  _RecordingOfflineWriter(super.repository);

  GroupExpenseOfflineOperation? savedOperation;

  @override
  Future<Id> save(GroupExpenseOfflineOperation operation) async {
    savedOperation = operation;
    return 1;
  }
}

class _OfflineUiAuthRepository implements AuthRepositoryBase {
  const _OfflineUiAuthRepository();

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => const AuthUser(
    id: currentUserId,
    email: 'offline@example.com',
    isEmailVerified: true,
  );

  @override
  Future<AuthUser> signInWithGoogle() =>
      login(email: 'offline@example.com', password: 'unused');

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> silentRefresh() async => null;

  @override
  Future<void> deleteAccount({String? currentPassword}) async {}

  @override
  Future<String> forgotPassword(String email) async => 'Sent';

  @override
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) async => 'Registered';

  @override
  Future<String> resendVerification(String email) async => 'Sent';

  @override
  Future<String> verifyEmail(String token) async => 'Verified';
}
