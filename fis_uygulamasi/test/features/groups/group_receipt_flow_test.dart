import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/domain/prepared_group_receipt.dart';
import 'package:app_main/features/groups/presentation/pages/fast_split_page.dart';
import 'package:app_main/features/groups/presentation/pages/group_receipt_capture_page.dart';
import 'package:app_main/features/groups/presentation/pages/group_receipt_review_page.dart';
import 'package:app_main/features/groups/presentation/pages/itemized_split_page.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/features/transaction_draft/presentation/transaction_draft_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  group('OCR ürün yönlendirme kararı', () {
    test('kullanılabilir ürün kalem bazlı bölüştürmeye uygundur', () {
      expect(hasUsableReceiptItems(const [ReceiptItem(name: 'Süt')]), isTrue);
    });

    test('boş, items: [{}] ve yalnız boşluk ürün hızlı bölüştürmeye gider', () {
      expect(hasUsableReceiptItems(const []), isFalse);
      expect(hasUsableReceiptItems(const [ReceiptItem(name: '')]), isFalse);
      expect(hasUsableReceiptItems(const [ReceiptItem(name: '   ')]), isFalse);
    });
  });

  testWidgets('grup fiş incelemede yalnız Grupla Paylaş ana işlemi vardır', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GroupReceiptReviewPage(
          groupId: twoMemberGroupId,
          receipt: PreparedGroupReceipt(
            draft: TransactionDraft(
              institutionName: 'Market',
              category: 'Market',
              amountInMinor: 12500,
              receiptItems: [
                ReceiptItem(name: 'Süt', totalAmountInMinor: 12500),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('share_with_group_button')), findsOneWidget);
    expect(find.text('Grupla Paylaş'), findsOneWidget);
    expect(find.text('Kişisel gider olarak kaydet'), findsNothing);
    expect(find.text('Gideri Kaydet'), findsNothing);
  });

  testWidgets('kişisel OCR ekranı mevcut Onayla işlemini korur', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TransactionDraftPage(
          initialDraft: TransactionDraft(
            institutionName: 'Market',
            category: 'Market',
            amountInMinor: 12500,
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('confirm_draft_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Onayla'), findsOneWidget);
    expect(find.text('Grupla Paylaş'), findsNothing);
  });

  testWidgets('kalem bazlı ekranda atanmamış ürün paylaşımı engeller', (
    tester,
  ) async {
    await _pumpWithGroup(
      tester,
      const ItemizedSplitPage(
        groupId: twoMemberGroupId,
        receipt: PreparedGroupReceipt(
          cloudReceiptId: '20000000-0000-4000-8000-000000000099',
          cloudLineItemIds: ['30000000-0000-4000-8000-000000000099'],
          draft: TransactionDraft(
            institutionName: 'Market',
            category: 'Market',
            amountInMinor: 1000,
            receiptItems: [
              ReceiptItem(name: 'Ekmek', totalAmountInMinor: 1000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unassigned_items_warning')), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('submit_itemized_share_button')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();
    final enabledButton = tester.widget<FilledButton>(
      find.byKey(const Key('submit_itemized_share_button')),
    );
    expect(enabledButton.onPressed, isNotNull);
  });

  testWidgets('hızlı bölüştürme üç yöntemi ve doğrulamalı butonu gösterir', (
    tester,
  ) async {
    await _pumpWithGroup(
      tester,
      const FastSplitPage(
        groupId: twoMemberGroupId,
        receipt: PreparedGroupReceipt(
          draft: TransactionDraft(
            institutionName: 'Taksi',
            category: 'Ulaşım',
            amountInMinor: 10001,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Eşit böl'), findsOneWidget);
    expect(find.text('Yüzdelik böl'), findsOneWidget);
    expect(find.text('Tutar bazlı böl'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('submit_fast_share_button')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Yüzdelik böl'));
    await tester.pump();
    expect(find.byKey(const Key('split_validation_message')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('submit_fast_share_button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('kamera iptalinde grup detayına güvenli döner', (tester) async {
    final router = GoRouter(
      initialLocation: '/groups/$twoMemberGroupId',
      routes: [
        GoRoute(
          path: '/groups/:groupId',
          builder: (_, _) => const Scaffold(body: Text('Grup detayı')),
        ),
        GoRoute(
          path: '/groups/:groupId/expenses/new',
          builder: (_, state) => GroupReceiptCapturePage(
            groupId: state.pathParameters['groupId']!,
            scanReceipt: (_) async => null,
            parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
              draft: TransactionDraft(
                institutionName: '',
                category: 'Diğer',
                amountInMinor: null,
              ),
              normalizedOcrText: '',
              confidenceScore: 0,
              isParseSuccessful: false,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(
            FakeGroupRepository(groups: const [twoMemberGroup]),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/groups/$twoMemberGroupId/expenses/new');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('start_group_receipt_scan_button')));
    await tester.pumpAndSettle();

    expect(find.text('Grup detayı'), findsOneWidget);
    expect(find.byType(GroupReceiptCapturePage), findsNothing);
  });
}

Future<void> _pumpWithGroup(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(
          FakeGroupRepository(groups: const [twoMemberGroup]),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
}
