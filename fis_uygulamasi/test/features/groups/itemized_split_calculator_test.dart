import 'package:app_main/features/groups/application/itemized_split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const firstLine = ItemizedReceiptLine(
    receiptLineItemId: 'line-1',
    name: 'Ekmek',
    quantityMilli: 1000,
    unitPriceInMinor: 100,
    totalAmountInMinor: 100,
  );

  group('ItemizedSplitCalculator', () {
    test('tek üyeye ürünün bütün para ve miktar payını verir', () {
      final state = ItemizedSplitState.initial(
        receiptTotalInMinor: 100,
        lineItems: const [firstLine],
        orderedActiveMemberIds: const ['a', 'b'],
      ).toggleLineItemMember(receiptLineItemId: 'line-1', userId: 'b');

      final result = state.calculation;
      expect(result.lineItemShares, hasLength(1));
      expect(result.lineItemShares.single.userId, 'b');
      expect(result.lineItemShares.single.amountInMinor, 100);
      expect(result.lineItemShares.single.quantityShareMilli, 1000);
      expect(result.isBalanced, isTrue);
    });

    test('bir kuruş ve bir milli artığını aktif üye sırasına göre dağıtır', () {
      const line = ItemizedReceiptLine(
        receiptLineItemId: 'line-1',
        name: 'Paylaşılan ürün',
        quantityMilli: 1001,
        unitPriceInMinor: 101,
        totalAmountInMinor: 101,
      );
      var state = ItemizedSplitState.initial(
        receiptTotalInMinor: 101,
        lineItems: const [line],
        orderedActiveMemberIds: const ['a', 'b'],
      );
      state = state.toggleLineItemMember(
        receiptLineItemId: 'line-1',
        userId: 'b',
      );
      state = state.toggleLineItemMember(
        receiptLineItemId: 'line-1',
        userId: 'a',
      );

      expect(
        state.calculation.lineItemShares.map((share) => share.userId),
        orderedEquals(['a', 'b']),
      );
      expect(
        state.calculation.lineItemShares.map((share) => share.amountInMinor),
        orderedEquals([51, 50]),
      );
      expect(
        state.calculation.lineItemShares.map(
          (share) => share.quantityShareMilli,
        ),
        orderedEquals([501, 500]),
      );
      expect(state.calculation.allocatedAmountInMinor, 101);
    });

    test('bilinmeyen miktarda quantity share null kalır', () {
      const line = ItemizedReceiptLine(
        receiptLineItemId: 'line-1',
        name: 'Ürün',
        quantityMilli: null,
        unitPriceInMinor: null,
        totalAmountInMinor: 100,
      );
      final state = ItemizedSplitState.initial(
        receiptTotalInMinor: 100,
        lineItems: const [line],
        orderedActiveMemberIds: const ['a'],
      ).toggleLineItemMember(receiptLineItemId: 'line-1', userId: 'a');

      expect(
        state.calculation.lineItemShares.single.quantityShareMilli,
        isNull,
      );
      expect(state.calculation.isBalanced, isTrue);
    });

    test('ekstra tutarı ürün sahibi katılımcılara varsayılan eşit dağıtır', () {
      var state = ItemizedSplitState.initial(
        receiptTotalInMinor: 201,
        lineItems: const [firstLine],
        orderedActiveMemberIds: const ['a', 'b'],
      );
      state = state.toggleLineItemMember(
        receiptLineItemId: 'line-1',
        userId: 'a',
      );
      state = state.toggleLineItemMember(
        receiptLineItemId: 'line-1',
        userId: 'b',
      );

      expect(state.calculation.extraAmountInMinor, 101);
      expect(
        state.calculation.extraAmountShares.map((share) => share.amountInMinor),
        orderedEquals([51, 50]),
      );
      expect(state.calculation.allocatedAmountInMinor, 201);
      expect(state.calculation.totalsByUserId, {'a': 101, 'b': 100});
    });

    test('ekstra tutar seçimi kullanıcı tarafından değiştirilebilir', () {
      var state = ItemizedSplitState.initial(
        receiptTotalInMinor: 200,
        lineItems: const [firstLine],
        orderedActiveMemberIds: const ['a', 'b'],
      ).toggleLineItemMember(receiptLineItemId: 'line-1', userId: 'a');
      state = state.toggleExtraMember('a');
      state = state.toggleExtraMember('b');

      expect(state.calculation.extraAmountShares.single.userId, 'b');
      expect(state.calculation.extraAmountShares.single.amountInMinor, 100);
      expect(state.calculation.isBalanced, isTrue);
    });

    test('atanmayan ürün ve negatif fark gönderimi engeller', () {
      final unassigned = ItemizedSplitState.initial(
        receiptTotalInMinor: 100,
        lineItems: const [firstLine],
        orderedActiveMemberIds: const ['a'],
      ).calculation;
      expect(unassigned.unassignedReceiptLineItemIds, {'line-1'});
      expect(unassigned.isBalanced, isFalse);

      final negative =
          ItemizedSplitState.initial(
                receiptTotalInMinor: 99,
                lineItems: const [firstLine],
                orderedActiveMemberIds: const ['a'],
              )
              .toggleLineItemMember(receiptLineItemId: 'line-1', userId: 'a')
              .calculation;
      expect(negative.extraAmountInMinor, -1);
      expect(negative.extraAmountShares, isEmpty);
      expect(negative.isBalanced, isFalse);
    });

    test('API assignment ve extra_amount_shares şekillerini üretir', () {
      final result =
          ItemizedSplitState.initial(
                receiptTotalInMinor: 150,
                lineItems: const [firstLine],
                orderedActiveMemberIds: const ['a'],
              )
              .toggleLineItemMember(receiptLineItemId: 'line-1', userId: 'a')
              .calculation;

      expect(result.toAssignments(expenseId: 'expense').single.toJson(), {
        'expense_id': 'expense',
        'receipt_line_item_id': 'line-1',
        'user_id': 'a',
        'amount_in_minor': 100,
        'quantity_share_milli': 1000,
      });
      expect(result.extraAmountShares.single.toJson(), {
        'user_id': 'a',
        'amount_in_minor': 50,
      });
    });

    test('pasif veya seçilebilir listede olmayan üyeyi reddeder', () {
      final state = ItemizedSplitState.initial(
        receiptTotalInMinor: 100,
        lineItems: const [firstLine],
        orderedActiveMemberIds: const ['active'],
      );
      expect(
        () => state.toggleLineItemMember(
          receiptLineItemId: 'line-1',
          userId: 'left',
        ),
        throwsFormatException,
      );
    });
  });
}
