import 'dart:async';

import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/fast_split_page.dart';
import 'package:app_main/features/groups/presentation/itemized_split_page.dart';
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
  testWidgets('seçilen başlangıç kaynağını otomatik olarak açar', (
    tester,
  ) async {
    var cameraCalls = 0;
    await _pumpPage(
      tester,
      initialSource: GroupReceiptSource.camera,
      scanReceipt: (_) async {
        cameraCalls++;
        return null;
      },
    );

    expect(cameraCalls, 1);
    expect(find.text('Fiş tarama işlemi iptal edildi.'), findsOneWidget);
  });

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
  testWidgets(
    'anlamlı OCR ürünlerini Itemized Split ekranına aktarır ve geri dönüşte taslağı korur',
    (tester) async {
      var fastSubmitCalls = 0;
      var itemizedSubmitCalls = 0;

      await _pumpPage(
        tester,
        scanReceipt: (_) async => 'MİGROS\nSÜT 25,50\nTOPLAM 25,50',
        parseReceipt: (_, {cancelToken}) async => ReceiptParseResult(
          draft: TransactionDraft(
            institutionName: 'MİGROS',
            category: 'Market',
            amountInMinor: 2550,
            transactionDate: DateTime(2026, 8, 14),
            receiptItems: const [
              ReceiptItem(
                name: 'Süt',
                quantity: 1,
                unitPriceInMinor: 2550,
                totalAmountInMinor: 2550,
              ),
            ],
          ),
          normalizedOcrText: 'MİGROS\nSÜT 25,50\nTOPLAM 25,50',
          confidenceScore: .95,
          isParseSuccessful: true,
        ),
        onFastSplitSubmit: (_, _, _) async {
          fastSubmitCalls++;
        },
        onItemizedSplitSubmit: (_, _, _) async {
          itemizedSubmitCalls++;
        },
      );

      await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('share_with_group_button')));
      await tester.pumpAndSettle();

      expect(find.byType(ItemizedSplitPage), findsOneWidget);
      expect(find.byType(FastSplitPage), findsNothing);

      final page = tester.widget<ItemizedSplitPage>(
        find.byType(ItemizedSplitPage),
      );
      expect(page.group, same(twoMemberGroup));
      expect(page.currentUserId, currentUserId);
      expect(page.initialTitle, 'MİGROS');
      expect(page.receipt.totalAmountInMinor, 2550);
      expect(page.receipt.lineItems.single.name, 'Süt');
      expect(page.receipt.lineItems.single.totalAmountInMinor, 2550);
      expect(fastSubmitCalls, 0);
      expect(itemizedSubmitCalls, 0);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('group_ocr_result')), findsOneWidget);
      expect(find.text('MİGROS'), findsOneWidget);
      expect(find.text('₺25,50'), findsOneWidget);
      expect(fastSubmitCalls, 0);
      expect(itemizedSubmitCalls, 0);
    },
  );
  testWidgets('ürün toplamı fiş toplamını aşarsa Fast Split geçişi sunar', (
    tester,
  ) async {
    var fastSubmitCalls = 0;
    var itemizedSubmitCalls = 0;

    await _pumpPage(
      tester,
      scanReceipt: (_) async => 'MARKET\nÜRÜN 60,00\nTOPLAM 50,00',
      parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
        draft: TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 5000,
          receiptItems: [
            ReceiptItem(
              name: 'Ürün',
              quantity: 1,
              unitPriceInMinor: 6000,
              totalAmountInMinor: 6000,
            ),
          ],
        ),
        normalizedOcrText: 'MARKET\nÜRÜN 60,00\nTOPLAM 50,00',
        confidenceScore: .80,
        isParseSuccessful: true,
      ),
      onFastSplitSubmit: (_, _, _) async {
        fastSubmitCalls++;
      },
      onItemizedSplitSubmit: (_, _, _) async {
        itemizedSubmitCalls++;
      },
    );

    await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('share_with_group_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ItemizedSplitPage), findsOneWidget);

    final fastSplitButton = find.byKey(
      const Key('itemized_use_fast_split_button'),
    );

    await tester.scrollUntilVisible(
      fastSplitButton,
      240,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('itemized_split_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    await tester.tap(fastSplitButton);
    await tester.pumpAndSettle();

    expect(find.byType(ItemizedSplitPage), findsNothing);
    expect(find.byType(FastSplitPage), findsOneWidget);

    final fastSplitPage = tester.widget<FastSplitPage>(
      find.byType(FastSplitPage),
    );

    expect(fastSplitPage.initialTitle, 'Market');
    expect(fastSplitPage.initialTotalAmountInMinor, 5000);
    expect(fastSubmitCalls, 0);
    expect(itemizedSubmitCalls, 0);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_ocr_result')), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('₺50,00'), findsOneWidget);
    expect(fastSubmitCalls, 0);
    expect(itemizedSubmitCalls, 0);
  });
  testWidgets('ürünsüz OCR sonucunu Fast Split ekranına aktarır', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      scanReceipt: (_) async => 'KİRA TOPLAM 5.000,00',
      parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
        draft: TransactionDraft(
          institutionName: 'Kira',
          category: 'Konut',
          amountInMinor: 500000,
        ),
        normalizedOcrText: 'KİRA TOPLAM 5.000,00',
        confidenceScore: .90,
        isParseSuccessful: true,
      ),
    );

    await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share_with_group_button')));
    await tester.pumpAndSettle();

    expect(find.byType(FastSplitPage), findsOneWidget);
    expect(find.byType(ItemizedSplitPage), findsNothing);

    final page = tester.widget<FastSplitPage>(find.byType(FastSplitPage));
    expect(page.group, same(twoMemberGroup));
    expect(page.currentUserId, currentUserId);
    expect(page.initialTitle, 'Kira');
    expect(page.initialTotalAmountInMinor, 500000);

    final titleField = tester.widget<TextFormField>(
      find.byKey(const Key('fast_split_title')),
    );
    final totalField = tester.widget<TextFormField>(
      find.byKey(const Key('fast_split_total')),
    );
    expect(titleField.controller?.text, 'Kira');
    expect(totalField.controller?.text, '5.000,00');
  });

  testWidgets('tutarı eksik OCR ürününü kullanılamaz sayıp Fast Split açar', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      scanReceipt: (_) async => 'MARKET\nFİYATI OKUNAMAYAN ÜRÜN\nTOPLAM 50,00',
      parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
        draft: TransactionDraft(
          institutionName: 'Market',
          category: 'Market',
          amountInMinor: 5000,
          receiptItems: [ReceiptItem(name: 'Fiyatı okunamayan ürün')],
        ),
        normalizedOcrText: 'MARKET\nFİYATI OKUNAMAYAN ÜRÜN\nTOPLAM 50,00',
        confidenceScore: .70,
        isParseSuccessful: true,
      ),
    );

    await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('share_with_group_button')));
    await tester.pumpAndSettle();

    expect(find.byType(FastSplitPage), findsOneWidget);
    expect(find.byType(ItemizedSplitPage), findsNothing);
  });

  testWidgets(
    'aktif kullanıcı yoksa split açmaz ve repository callback çağırmaz',
    (tester) async {
      var fastSubmitCalls = 0;
      var itemizedSubmitCalls = 0;

      await _pumpPage(
        tester,
        authenticatedUserId: null,
        scanReceipt: (_) async => 'KİRA TOPLAM 100,00',
        parseReceipt: (_, {cancelToken}) async => const ReceiptParseResult(
          draft: TransactionDraft(
            institutionName: 'Kira',
            category: 'Konut',
            amountInMinor: 10000,
          ),
          normalizedOcrText: 'KİRA TOPLAM 100,00',
          confidenceScore: .90,
          isParseSuccessful: true,
        ),
        onFastSplitSubmit: (_, _, _) async {
          fastSubmitCalls++;
        },
        onItemizedSplitSubmit: (_, _, _) async {
          itemizedSubmitCalls++;
        },
      );

      await tester.tap(find.byKey(const Key('group_ocr_camera_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('share_with_group_button')));
      await tester.pump();

      expect(find.byType(FastSplitPage), findsNothing);
      expect(find.byType(ItemizedSplitPage), findsNothing);
      expect(
        find.text(
          'Aktif kullanıcı bilgisi bulunamadı. Lütfen yeniden giriş yapın.',
        ),
        findsOneWidget,
      );
      expect(fastSubmitCalls, 0);
      expect(itemizedSubmitCalls, 0);
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  GroupDetail group = twoMemberGroup,
  String? authenticatedUserId = currentUserId,
  GroupReceiptLauncher? scanReceipt,
  GroupReceiptLauncher? pickGalleryReceipt,
  GroupReceiptParser? parseReceipt,
  GroupFastSplitSubmit? onFastSplitSubmit,
  GroupItemizedSplitSubmit? onItemizedSplitSubmit,
  ThemeMode themeMode = ThemeMode.light,
  GroupReceiptSource? initialSource,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentGroupUserIdProvider.overrideWithValue(authenticatedUserId),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: GroupOcrPage(
          group: group,
          initialSource: initialSource,
          scanReceipt: scanReceipt,
          pickGalleryReceipt: pickGalleryReceipt,
          parseReceipt: parseReceipt,
          onFastSplitSubmit: onFastSplitSubmit ?? (_, _, _) async {},
          onItemizedSplitSubmit: onItemizedSplitSubmit ?? (_, _, _) async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
