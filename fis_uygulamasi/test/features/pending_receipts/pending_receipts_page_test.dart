import 'package:app_main/features/pending_receipts/application/pending_receipts_controller.dart';
import 'package:app_main/features/pending_receipts/data/pending_receipts_gateway.dart';
import 'package:app_main/features/pending_receipts/domain/pending_receipt.dart';
import 'package:app_main/features/pending_receipts/presentation/pending_receipts_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'bir fişi onaylamak taslağı kaydeder ve listeden kaldırır',
    (tester) async {
      final gateway = _FakeGateway(
        initial: [
          PendingReceipt(
            id: 'receipt-1',
            merchantName: 'Örnek Market',
            totalAmountInMinor: 12550,
            currency: 'TRY',
            receiptDate: DateTime(2026, 8, 17),
            category: 'Market',
            createdAt: DateTime(2026, 8, 17, 12, 30),
          ),
        ],
      );
      final saved = <TransactionEntity>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingReceiptsGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp(
            home: PendingReceiptsPage(
              saveTransaction: (transaction) async {
                saved.add(transaction);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Örnek Market'), findsOneWidget);

      await tester.tap(find.text('Örnek Market'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('confirm_draft_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_draft_button')));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single.source, TransactionSource.ocrLlm);
      expect(saved.single.amountInMinor, 12550);
      expect(gateway.approvedIds, ['receipt-1']);
      expect(find.text('Örnek Market'), findsNothing);
      expect(find.text('Onay bekleyen fatura yok.'), findsOneWidget);
    },
  );

  testWidgets('bir fişi reddetmek listeden kaldırır ve backend’i çağırır', (
    tester,
  ) async {
    final gateway = _FakeGateway(
      initial: [
        PendingReceipt(
          id: 'receipt-2',
          merchantName: 'İkinci Market',
          totalAmountInMinor: 500,
          currency: 'TRY',
          createdAt: DateTime(2026, 8, 17),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pendingReceiptsGatewayProvider.overrideWithValue(gateway)],
        child: const MaterialApp(
          home: PendingReceiptsPage(saveTransaction: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('İkinci Market'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Faturayı reddet'), findsOneWidget);
    await tester.tap(find.text('Reddet'));
    await tester.pumpAndSettle();

    expect(gateway.rejectedIds, ['receipt-2']);
    expect(find.text('Onay bekleyen fatura yok.'), findsOneWidget);
  });

  testWidgets('boş liste bilgilendirici bir metin gösterir', (tester) async {
    final gateway = _FakeGateway(initial: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [pendingReceiptsGatewayProvider.overrideWithValue(gateway)],
        child: const MaterialApp(
          home: PendingReceiptsPage(saveTransaction: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Onay bekleyen fatura yok.'), findsOneWidget);
  });
}

class _FakeGateway implements PendingReceiptsGateway {
  _FakeGateway({required List<PendingReceipt> initial})
    : _receipts = List.of(initial);

  final List<PendingReceipt> _receipts;
  final List<String> approvedIds = [];
  final List<String> rejectedIds = [];

  @override
  Future<List<PendingReceipt>> list() async => List.of(_receipts);

  @override
  Future<PendingReceipt> approve(
    String id, {
    String? merchantName,
    int? totalAmountInMinor,
    String? currency,
    DateTime? receiptDate,
    String? category,
  }) async {
    approvedIds.add(id);
    final receipt = _receipts.firstWhere((item) => item.id == id);
    _receipts.removeWhere((item) => item.id == id);
    return receipt;
  }

  @override
  Future<PendingReceipt> reject(String id) async {
    rejectedIds.add(id);
    final receipt = _receipts.firstWhere((item) => item.id == id);
    _receipts.removeWhere((item) => item.id == id);
    return receipt;
  }
}
