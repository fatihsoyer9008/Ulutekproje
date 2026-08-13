import 'dart:async';

import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/presentation/group_ocr_page.dart';
import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:app_main/features/transaction_draft/model/transaction_draft.dart';
import 'package:core_ui/core_ui.dart';
import 'package:finance_database/finance_database.dart' show ReceiptItem;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('grup adı ile kamera ve galeri seçeneklerini gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpPage(tester, themeMode: ThemeMode.dark);

    expect(find.text('Ev Arkadaşları'), findsOneWidget);
    expect(find.byKey(const Key('group_ocr_camera_button')), findsOneWidget);
    expect(find.byKey(const Key('group_ocr_gallery_button')), findsOneWidget);
    expect(find.text('Gideri Kaydet'), findsNothing);
    expect(find.text('Fişim yok, elle gireceğim'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OCR sürerken loading, tamamlanınca fiş özetini gösterir', (
    tester,
  ) async {
    final parseResult = Completer<ReceiptParseResult>();
    await _pumpPage(
      tester,
      scanReceipt: (_) async => 'MİGROS TOPLAM 25,50 TL',
      parseReceipt: (_, {cancelToken}) => parseResult.future,
    );

    await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
    await tester.pump();

    expect(find.byKey(const Key('group_ocr_loading')), findsOneWidget);

    parseResult.complete(
      ReceiptParseResult(
        draft: TransactionDraft(
          institutionName: 'MİGROS',
          category: 'Market',
          amountInMinor: 2550,
          transactionDate: DateTime(2026, 8, 13),
          receiptItems: const [
            ReceiptItem(
              name: 'Süt',
              category: 'Gıda',
              quantity: 1,
              unitPriceInMinor: 2550,
              totalAmountInMinor: 2550,
            ),
          ],
        ),
        normalizedOcrText: 'MİGROS\nTOPLAM 25,50 TL',
        confidenceScore: .95,
        isParseSuccessful: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MİGROS'), findsOneWidget);
    expect(find.text('13.08.2026'), findsOneWidget);
    expect(find.text('₺25,50'), findsOneWidget);
    expect(find.text('Ürün sayısı'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byKey(const Key('share_with_group_button')), findsOneWidget);
    expect(find.text('Grupla Paylaş'), findsOneWidget);
    expect(find.text('Gideri Kaydet'), findsNothing);
  });

  testWidgets('galeri iptalini kullanıcı dostu biçimde gösterir', (
    tester,
  ) async {
    var galleryCalls = 0;
    await _pumpPage(
      tester,
      pickGalleryReceipt: (_) async {
        galleryCalls++;
        return null;
      },
    );

    await tester.tap(find.byKey(const Key('group_ocr_gallery_button')));
    await tester.pumpAndSettle();

    expect(galleryCalls, 1);
    expect(find.text('Fiş tarama işlemi iptal edildi.'), findsOneWidget);
  });

  testWidgets('devam eden OCR akışı ekrandan iptal edilebilir', (tester) async {
    final scanResult = Completer<String?>();
    await _pumpPage(tester, scanReceipt: (_) => scanResult.future);

    await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('group_ocr_cancel_button')));
    await tester.pump();

    expect(find.text('Fiş analizi iptal edildi.'), findsOneWidget);
    expect(find.byKey(const Key('group_ocr_camera_button')), findsOneWidget);

    scanResult.complete('gecikmiş sonuç');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_ocr_result')), findsNothing);
  });

  testWidgets('OCR hatasını gösterip yeniden taramaya izin verir', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      scanReceipt: (_) async => 'OCR',
      parseReceipt: (_, {cancelToken}) async =>
          throw const ReceiptParserException('Sunucuya ulaşılamadı.'),
    );

    await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
    await tester.pumpAndSettle();

    expect(find.text('Sunucuya ulaşılamadı.'), findsOneWidget);
    expect(find.byKey(const Key('group_ocr_camera_button')), findsOneWidget);
    expect(find.byKey(const Key('group_ocr_gallery_button')), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  GroupReceiptLauncher? scanReceipt,
  GroupReceiptLauncher? pickGalleryReceipt,
  GroupReceiptParser? parseReceipt,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(
          FakeGroupRepository(groups: const [twoMemberGroup]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: GroupOcrPage(
          groupId: twoMemberGroupId,
          scanReceipt: scanReceipt,
          pickGalleryReceipt: pickGalleryReceipt,
          parseReceipt: parseReceipt,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
