import 'dart:async';

import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/debt_summary_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('yükleme durumunu gösterir', (tester) async {
    final completer = Completer<DebtSummary>();
    await _pumpPage(tester, loadSummary: () => completer.future);

    expect(find.byKey(const Key('debt_summary_loading')), findsOneWidget);
    completer.complete(currentUserDebtorDebtSummary);
    await tester.pumpAndSettle();
  });

  testWidgets('borç kartlarını ve DebtTransfer listesini gösterir', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      loadSummary: () async => currentUserDebtorDebtSummary,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('your_debt_card')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('your_debt_card')),
        matching: find.text('₺ 62.50'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('owed_to_you_card')), findsOneWidget);
    expect(find.text('Zafer Tuna → Abdullah Seydi'), findsOneWidget);
    expect(find.text('Ödeme yapıldı'), findsOneWidget);
  });

  testWidgets('alacaklı kullanıcı için sana borçlu olanlar kartını doldurur', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      loadSummary: () async => currentUserCreditorDebtSummary,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('owed_to_you_card')),
        matching: find.text('₺ 62.50'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ödeme yapıldı'), findsNothing);
  });

  testWidgets('onaylanan settlement sonrası özeti yeniden yükler', (
    tester,
  ) async {
    var loadCount = 0;
    DebtTransfer? paidTransfer;
    await _pumpPage(
      tester,
      loadSummary: () async {
        loadCount += 1;
        return loadCount == 1 ? currentUserDebtorDebtSummary : _emptySummary;
      },
      onMarkPaid: (transfer) async => paidTransfer = transfer,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ödeme yapıldı'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('settlement_confirmation_dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm_settlement')));
    await tester.pumpAndSettle();

    expect(paidTransfer, isNotNull);
    expect(loadCount, 2);
    expect(find.byKey(const Key('debt_summary_empty')), findsOneWidget);
  });

  testWidgets('onay iptal edilirse settlement oluşturmaz', (tester) async {
    var paid = false;
    await _pumpPage(
      tester,
      loadSummary: () async => currentUserDebtorDebtSummary,
      onMarkPaid: (_) async => paid = true,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ödeme yapıldı'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(paid, isFalse);
  });

  testWidgets('hata durumundan tekrar denenebilir', (tester) async {
    var attempt = 0;
    await _pumpPage(
      tester,
      loadSummary: () async {
        attempt += 1;
        if (attempt == 1) throw Exception('network');
        return _emptySummary;
      },
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_summary_error')), findsOneWidget);
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debt_summary_empty')), findsOneWidget);
  });

  testWidgets('boş durumu gösterir', (tester) async {
    await _pumpPage(tester, loadSummary: () async => _emptySummary);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt_summary_empty')), findsOneWidget);
    expect(find.text('Henüz borç hareketi yok'), findsOneWidget);
  });
}

const _emptySummary = DebtSummary(
  groupId: twoMemberGroupId,
  currency: 'TRY',
  balances: <DebtBalance>[],
  suggestedTransfers: <DebtTransfer>[],
  generatedAt: '2026-08-11T10:00:00Z',
);

Future<void> _pumpPage(
  WidgetTester tester, {
  required DebtSummaryLoader loadSummary,
  MarkDebtTransferPaid? onMarkPaid,
}) => tester.pumpWidget(
  MaterialApp(
    home: DebtSummaryPage(
      groupName: 'Ev Arkadaşları',
      currentUserId: currentUserId,
      loadSummary: loadSummary,
      onMarkPaid: onMarkPaid ?? (_) async {},
    ),
  ),
);
