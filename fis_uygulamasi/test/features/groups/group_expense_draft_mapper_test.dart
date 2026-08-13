import 'package:finance_database/finance_database.dart';
import 'package:app_main/features/groups/application/group_expense_draft_mapper.dart';
import 'package:app_main/features/groups/domain/group_expense_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = GroupExpenseDraftMapper();

  group('GroupExpenseDraftMapper', () {
    test(
      'ürünlü ve kullanıcı tarafından düzenlenmiş OCR taslağını aktarır',
      () {
        final transactionDate = DateTime.utc(2026, 8, 13, 10, 30);
        final source = TransactionDraft(
          institutionName: '  A101 Bursa  ',
          category: '  Market  ',
          amountInMinor: 12550,
          transactionDate: transactionDate,
          rawOcrText: '  OCR metni  ',
          receiptItems: const [
            ReceiptItem(
              name: '  Süt  ',
              category: '  Gıda  ',
              quantity: 2,
              unitPriceInMinor: 3000,
              totalAmountInMinor: 6000,
              taxRate: .20,
              taxAmountInMinor: 1000,
            ),
            ReceiptItem(name: 'Ekmek', quantity: 1, priceMinor: 1550),
          ],
        );

        final result = mapper.fromTransactionDraft(
          source: source,
          groupId: ' group-1 ',
          payerUserId: ' user-1 ',
        );

        expect(result.groupId, 'group-1');
        expect(result.payerUserId, 'user-1');
        expect(result.merchantName, 'A101 Bursa');
        expect(result.category, 'Market');
        expect(result.totalAmountInMinor, 12550);
        expect(result.expenseDate, transactionDate);
        expect(result.currency, 'TRY');
        expect(result.rawOcrText, 'OCR metni');
        expect(result.hasMeaningfulItems, isTrue);
        expect(result.items, hasLength(2));
        expect(result.items.first.name, 'Süt');
        expect(result.items.first.category, 'Gıda');
        expect(result.items.first.quantityMilli, 2000);
        expect(result.items.first.unitPriceInMinor, 3000);
        expect(result.items.first.totalAmountInMinor, 6000);
        expect(result.items.first.taxRateBasisPoints, 2000);
        expect(result.items.first.taxAmountInMinor, 1000);
        expect(result.items.last.unitPriceInMinor, 1550);
        expect(result.items.last.totalAmountInMinor, 1550);
      },
    );

    test('ürünsüz OCR sonucunu Fast Split için boş ürün listesiyle üretir', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Kira',
          category: 'Konut',
          amountInMinor: 2500000,
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(result.items, isEmpty);
      expect(result.hasMeaningfulItems, isFalse);
      expect(result.totalAmountInMinor, 2500000);
    });

    test('miktar ve birim fiyattan satır toplamını minor-unit hesaplar', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 2500,
          receiptItems: [
            ReceiptItem(name: 'Yoğurt', quantity: 2, unitPriceInMinor: 1250),
          ],
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(result.items.single.quantityMilli, 2000);
      expect(result.items.single.unitPriceInMinor, 1250);
      expect(result.items.single.totalAmountInMinor, 2500);
      expect(result.hasMeaningfulItems, isTrue);
    });

    test('legacy fiyatı miktarla çarpar ve doğrudan satır toplamı saymaz', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 3750,
          receiptItems: [
            ReceiptItem(name: 'Meyve Suyu', quantity: 3, priceMinor: 1250),
          ],
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(result.items.single.unitPriceInMinor, 1250);
      expect(result.items.single.totalAmountInMinor, 3750);
      expect(result.hasMeaningfulItems, isTrue);
    });

    test('yalnızca adı olan ürünü korur fakat itemized adayı saymaz', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 5000,
          receiptItems: [ReceiptItem(name: 'Fiyatı okunamayan ürün')],
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.totalAmountInMinor, isNull);
      expect(result.hasMeaningfulItems, isFalse);
    });

    test('geçerli ve eksik toplamlı karışık listeyi itemized adayı saymaz', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 5000,
          receiptItems: [
            ReceiptItem(name: 'Hesaplanabilen', totalAmountInMinor: 2500),
            ReceiptItem(name: 'Fiyatı okunamayan'),
          ],
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(result.items, hasLength(2));
      expect(result.items.first.totalAmountInMinor, 2500);
      expect(result.items.last.totalAmountInMinor, isNull);
      expect(result.hasMeaningfulItems, isFalse);
    });

    test('binde birimin altında sıfıra yuvarlanan miktarı null yapar', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 100,
          receiptItems: [
            ReceiptItem(
              name: 'Hassas ürün',
              quantity: 0.0004,
              totalAmountInMinor: 100,
            ),
          ],
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(result.items.single.quantityMilli, isNull);
      expect(result.items.single.totalAmountInMinor, 100);
      expect(result.hasMeaningfulItems, isTrue);
    });

    test('items: [{}] karşılığı boş isimli ürünleri kullanılamaz sayar', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 5000,
          receiptItems: [
            ReceiptItem(name: ''),
            ReceiptItem(name: '   ', totalAmountInMinor: 5000),
          ],
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(result.items, isEmpty);
      expect(result.hasMeaningfulItems, isFalse);
    });

    test('geçersiz ürün değerlerini taşımadan anlamlı ürünü korur', () {
      final result = mapper.fromTransactionDraft(
        source: const TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 1000,
          receiptItems: [
            ReceiptItem(
              name: 'Ürün',
              quantity: -2,
              unitPriceInMinor: -100,
              totalAmountInMinor: -200,
              taxRate: -0.1,
              taxAmountInMinor: -10,
            ),
          ],
        ),
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      final item = result.items.single;
      expect(item.name, 'Ürün');
      expect(item.quantityMilli, isNull);
      expect(item.unitPriceInMinor, isNull);
      expect(item.totalAmountInMinor, isNull);
      expect(item.taxRateBasisPoints, isNull);
      expect(item.taxAmountInMinor, isNull);
    });

    test('kaynak listeyi değiştirmez ve çıktı listesini immutable tutar', () {
      final sourceItems = <ReceiptItem>[const ReceiptItem(name: 'Süt')];
      final source = TransactionDraft(
        institutionName: 'Market',
        category: 'Market',
        amountInMinor: 1000,
        receiptItems: sourceItems,
      );

      final result = mapper.fromTransactionDraft(
        source: source,
        groupId: 'group-1',
        payerUserId: 'user-1',
      );

      expect(source.receiptItems, hasLength(1));
      expect(
        () => result.items.add(
          const GroupExpenseDraftItem(
            name: 'Ekmek',
            category: null,
            quantityMilli: null,
            unitPriceInMinor: null,
            totalAmountInMinor: null,
            taxRateBasisPoints: null,
            taxAmountInMinor: null,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('boş groupId ve payerUserId değerlerini reddeder', () {
      const source = TransactionDraft(
        institutionName: 'Market',
        category: 'Market',
        amountInMinor: 1000,
      );

      expect(
        () => mapper.fromTransactionDraft(
          source: source,
          groupId: ' ',
          payerUserId: 'user-1',
        ),
        throwsArgumentError,
      );
      expect(
        () => mapper.fromTransactionDraft(
          source: source,
          groupId: 'group-1',
          payerUserId: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
