import 'package:app_main/features/groups/application/fast_split_calculator.dart';
import 'package:app_main/features/groups/application/group_expense_flow_controller.dart';
import 'package:app_main/features/groups/application/itemized_split_calculator.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_expense_draft.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  GroupExpenseDraft createDraft() {
    return GroupExpenseDraft(
      groupId: twoMemberGroupId,
      payerUserId: currentUserId,
      merchantName: 'Haftalık market',
      category: 'Market',
      totalAmountInMinor: 12000,
      expenseDate: DateTime.utc(2026, 8, 14),
      currency: 'TRY',
      rawOcrText: null,
      items: const <GroupExpenseDraftItem>[],
    );
  }

  FastSplitCalculation createFastCalculation() {
    return FastSplitCalculator.equal(
      totalAmountInMinor: 12000,
      memberIds: const <String>[currentUserId, secondUserId],
    );
  }

  void prepareFastSplit(GroupExpenseFlowController controller) {
    controller.start(
      group: twoMemberGroup,
      activeUserId: currentUserId,
      draft: createDraft(),
    );
    controller.setFastSplit(createFastCalculation());
  }

  void prepareItemizedSplit(GroupExpenseFlowController controller) {
    controller.start(
      group: twoMemberGroup,
      activeUserId: currentUserId,
      draft: createDraft(),
    );

    const calculation = ItemizedSplitCalculation(
      receiptTotalInMinor: 12000,
      lineItemsTotalInMinor: 10000,
      lineItemShares: <ItemizedLineItemShare>[
        ItemizedLineItemShare(
          receiptLineItemId: 'line-1',
          userId: currentUserId,
          amountInMinor: 10000,
          quantityShareMilli: 1000,
        ),
      ],
      extraAmountShares: <ExtraAmountShare>[
        ExtraAmountShare(userId: secondUserId, amountInMinor: 2000),
      ],
      unassignedReceiptLineItemIds: <String>{},
      hasUnknownLineTotals: false,
      hasUnsyncedLineItems: false,
    );

    controller.setItemizedSplit(
      receiptId: 'receipt-1',
      calculation: calculation,
    );
  }

  test(
    'akış seçili grup, aktif kullanıcı ve taslağı editing state içinde tutar',
    () {
      final controller = GroupExpenseFlowController(
        FakeGroupRepository(groups: const <GroupDetail>[twoMemberGroup]),
      );

      controller.start(
        group: twoMemberGroup,
        activeUserId: currentUserId,
        draft: createDraft(),
      );

      expect(controller.state.status, GroupExpenseFlowStatus.editing);
      expect(controller.state.groupId, twoMemberGroupId);
      expect(controller.state.group?.id, twoMemberGroupId);
      expect(controller.state.activeUserId, currentUserId);
      expect(controller.state.payerUserId, currentUserId);
      expect(controller.state.draft?.merchantName, 'Haftalık market');
    },
  );

  test(
    'Fast Split paylarını controller state içinde minor-unit olarak tutar',
    () {
      final controller = GroupExpenseFlowController(
        FakeGroupRepository(groups: const <GroupDetail>[twoMemberGroup]),
      );

      prepareFastSplit(controller);

      expect(controller.state.splitType, SplitType.equal);
      expect(controller.state.fastSplitSharesInMinor, <String, int>{
        currentUserId: 6000,
        secondUserId: 6000,
      });
      expect(controller.state.currentUserShareInMinor, 6000);
    },
  );

  test(
    'Itemized Split ürün ve ek tutar paylarını hesaplayıcı sonucundan saklar',
    () {
      final controller = GroupExpenseFlowController(
        FakeGroupRepository(groups: const <GroupDetail>[twoMemberGroup]),
      );

      controller.start(
        group: twoMemberGroup,
        activeUserId: currentUserId,
        draft: createDraft(),
      );

      const calculation = ItemizedSplitCalculation(
        receiptTotalInMinor: 12000,
        lineItemsTotalInMinor: 10000,
        lineItemShares: <ItemizedLineItemShare>[
          ItemizedLineItemShare(
            receiptLineItemId: 'line-1',
            userId: currentUserId,
            amountInMinor: 10000,
            quantityShareMilli: 1000,
          ),
        ],
        extraAmountShares: <ExtraAmountShare>[
          ExtraAmountShare(userId: secondUserId, amountInMinor: 2000),
        ],
        unassignedReceiptLineItemIds: <String>{},
        hasUnknownLineTotals: false,
        hasUnsyncedLineItems: false,
      );

      controller.setItemizedSplit(
        receiptId: 'receipt-1',
        calculation: calculation,
      );

      expect(controller.state.splitType, SplitType.itemized);
      expect(controller.state.receiptId, 'receipt-1');
      expect(controller.state.extraAmountInMinor, 2000);
      expect(controller.state.itemizedLineShares, hasLength(1));
      expect(controller.state.extraAmountShares, hasLength(1));
      expect(controller.state.currentUserShareInMinor, 10000);
    },
  );

  test(
    'Fake GroupExpenseRepository ile başarılı Fast Split kaydı success state üretir',
    () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      );
      final controller = GroupExpenseFlowController(repository);

      prepareFastSplit(controller);
      await controller.submitFastSplit(idempotencyKey: 'flow-success');

      expect(controller.state.status, GroupExpenseFlowStatus.success);
      expect(controller.state.createdExpense?.title, 'Haftalık market');
      expect(await repository.listExpenses(twoMemberGroupId), hasLength(1));
    },
  );

  test('repository hatası taslağı ve Fast Split paylarını korur', () async {
    final controller = GroupExpenseFlowController(
      FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        error: groupsApiErrorException,
      ),
    );

    prepareFastSplit(controller);
    final draftBeforeSubmit = controller.state.draft;
    final sharesBeforeSubmit = controller.state.fastSplitSharesInMinor;

    await controller.submitFastSplit(idempotencyKey: 'flow-error');

    expect(controller.state.status, GroupExpenseFlowStatus.error);
    expect(controller.state.error, isA<GroupApiException>());
    expect(controller.state.draft, same(draftBeforeSubmit));
    expect(controller.state.fastSplitSharesInMinor, sharesBeforeSubmit);
  });

  test('loading durumunda ikinci submit isteği engellenir', () async {
    final repository = FakeGroupRepository(
      groups: const <GroupDetail>[twoMemberGroup],
      latency: const Duration(milliseconds: 30),
    );
    final controller = GroupExpenseFlowController(repository);

    prepareFastSplit(controller);

    final firstSubmit = controller.submitFastSplit(
      idempotencyKey: 'flow-double-submit',
    );
    final secondSubmit = controller.submitFastSplit(
      idempotencyKey: 'flow-double-submit',
    );

    await Future.wait<void>(<Future<void>>[firstSubmit, secondSubmit]);

    expect(controller.state.status, GroupExpenseFlowStatus.success);
    expect(await repository.listExpenses(twoMemberGroupId), hasLength(1));
  });

  test(
    'Fake GroupExpenseRepository ile başarılı Itemized Split kaydı success state üretir',
    () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      );
      final controller = GroupExpenseFlowController(repository);

      prepareItemizedSplit(controller);
      await controller.submitItemizedSplit(
        idempotencyKey: 'itemized-flow-success',
      );

      expect(controller.state.status, GroupExpenseFlowStatus.success);
      expect(controller.state.createdExpense?.splitType, SplitType.itemized);
      expect(
        controller.state.createdExpense?.lineItemAssignments,
        hasLength(1),
      );
      expect(controller.state.createdExpense?.extraAmounts, hasLength(1));
    },
  );

  test(
    'Itemized Split repository hatasında taslağı ve atamaları korur',
    () async {
      final controller = GroupExpenseFlowController(
        FakeGroupRepository(
          groups: const <GroupDetail>[twoMemberGroup],
          error: groupsApiErrorException,
        ),
      );

      prepareItemizedSplit(controller);
      final draftBeforeSubmit = controller.state.draft;

      await controller.submitItemizedSplit(
        idempotencyKey: 'itemized-flow-error',
      );

      expect(controller.state.status, GroupExpenseFlowStatus.error);
      expect(controller.state.error, isA<GroupApiException>());
      expect(controller.state.draft, same(draftBeforeSubmit));
      expect(controller.state.itemizedLineShares, hasLength(1));
      expect(controller.state.itemizedLineShares.single.amountInMinor, 10000);
      expect(controller.state.extraAmountShares, hasLength(1));
      expect(controller.state.extraAmountShares.single.amountInMinor, 2000);
    },
  );

  test(
    'provider override ile verilen repository kullanılır ve akış temizlenir',
    () async {
      final repository = FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      );
      final container = ProviderContainer(
        overrides: [
          groupExpenseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen<GroupExpenseFlowState>(
        groupExpenseFlowControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      final controller = container.read(
        groupExpenseFlowControllerProvider.notifier,
      );

      prepareFastSplit(controller);
      await controller.submitFastSplit(
        idempotencyKey: 'flow-provider-override',
      );

      expect(
        container.read(groupExpenseFlowControllerProvider).status,
        GroupExpenseFlowStatus.success,
      );

      controller.clear();

      expect(
        container.read(groupExpenseFlowControllerProvider).status,
        GroupExpenseFlowStatus.idle,
      );

      prepareFastSplit(controller);
      controller.cancel();

      expect(
        container.read(groupExpenseFlowControllerProvider).status,
        GroupExpenseFlowStatus.cancelled,
      );

      controller.clear();

      expect(
        container.read(groupExpenseFlowControllerProvider).status,
        GroupExpenseFlowStatus.idle,
      );
      expect(container.read(groupExpenseFlowControllerProvider).draft, isNull);
    },
  );
}
