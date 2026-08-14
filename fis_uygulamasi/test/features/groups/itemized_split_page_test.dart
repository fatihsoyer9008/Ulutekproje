import 'package:app_main/features/groups/application/itemized_split_calculator.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/itemized_split_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

const _receipt = ItemizedSplitReceipt(
  receiptId: 'receipt-cloud-1',
  totalAmountInMinor: 12501,
  lineItems: [
    ItemizedReceiptLine(
      receiptLineItemId: 'line-1',
      name: 'Organik tam buğday ekmeği',
      quantityMilli: 2000,
      unitPriceInMinor: 3000,
      totalAmountInMinor: 6000,
    ),
    ItemizedReceiptLine(
      receiptLineItemId: 'line-2',
      name: 'Süt',
      quantityMilli: null,
      unitPriceInMinor: null,
      totalAmountInMinor: 6000,
    ),
  ],
);

const _draftReceipt = ItemizedSplitReceipt(
  receiptId: null,
  totalAmountInMinor: 6000,
  lineItems: [
    ItemizedReceiptLine(
      receiptLineItemId: null,
      receiptLineItemPosition: 0,
      name: 'Süt',
      quantityMilli: 1000,
      unitPriceInMinor: 6000,
      totalAmountInMinor: 6000,
    ),
  ],
);

void main() {
  testWidgets('ürün alanlarını ve eksik değerleri doğru gösterir', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.text('Organik tam buğday ekmeği'), findsOneWidget);
    expect(find.text('Miktar: 2'), findsOneWidget);
    expect(find.textContaining('Birim fiyat: ₺ 30.00'), findsOneWidget);
    expect(find.textContaining('Satır toplamı: ₺ 60.00'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('itemized_line_item_1')));
    expect(find.text('Miktar: Belirtilmedi'), findsOneWidget);
    expect(find.text('Birim fiyat: Belirtilmedi'), findsOneWidget);
  });

  testWidgets('tek ve birden fazla üyeye atar, atamayı kaldırır', (
    tester,
  ) async {
    await _pumpPage(tester);
    final firstMember = find.byKey(
      Key('itemized_line_0_member_$currentUserId'),
    );
    final secondMember = find.byKey(
      Key('itemized_line_0_member_$secondUserId'),
    );

    await _scrollTo(tester, firstMember);
    await tester.tap(firstMember);
    await tester.tap(secondMember);
    await tester.pump();
    expect(tester.widget<FilterChip>(firstMember).selected, isTrue);
    expect(tester.widget<FilterChip>(secondMember).selected, isTrue);

    await tester.tap(firstMember);
    await tester.pump();
    expect(tester.widget<FilterChip>(firstMember).selected, isFalse);
    expect(tester.widget<FilterChip>(secondMember).selected, isTrue);
  });

  testWidgets('atanmayan ürün uyarısı görünür ve gönderim engellenir', (
    tester,
  ) async {
    var submitted = false;
    await _pumpPage(tester, onSubmit: (_) async => submitted = true);

    expect(
      find.byKey(const Key('itemized_unassigned_warning')),
      findsOneWidget,
    );
    expect(find.textContaining('2 ürün henüz'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('itemized_split_submit')));
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('itemized_split_submit')),
    );
    expect(button.onPressed, isNull);
    expect(submitted, isFalse);
  });

  testWidgets('ekstra tutarı dağıtır ve API uyumlu toplamı gönderir', (
    tester,
  ) async {
    ItemizedSplitFormValue? submitted;
    await _pumpPage(tester, onSubmit: (value) async => submitted = value);
    await tester.enterText(
      find.byKey(const Key('itemized_split_title')),
      'Market fişi',
    );
    await _assignAllItems(tester);

    await _scrollTo(
      tester,
      find.byKey(const Key('itemized_extra_amount_card')),
    );
    expect(find.byKey(const Key('itemized_extra_amount_card')), findsOneWidget);
    expect(find.text('₺ 5.01'), findsOneWidget);
    expect(
      tester
          .widget<FilterChip>(
            find.byKey(Key('itemized_extra_member_$currentUserId')),
          )
          .selected,
      isTrue,
    );

    final submit = find.byKey(const Key('itemized_split_submit'));
    await _scrollTo(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.receiptId, 'receipt-cloud-1');
    expect(submitted!.calculation.allocatedAmountInMinor, 12501);
    expect(submitted!.calculation.isBalanced, isTrue);
    expect(
      submitted!.calculation.extraAmountShares.map(
        (share) => share.amountInMinor,
      ),
      orderedEquals([251, 250]),
    );
  });

  testWidgets('backend unassigned_line_items hatasını ürüne geri yansıtır', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      onSubmit: (_) async => throw const GroupApiException(
        statusCode: 422,
        error: GroupApiError(
          detail: GroupApiErrorDetail(
            code: 'unassigned_line_items',
            message: 'Atanmayan ürünler var.',
            unassignedReceiptLineItemIds: ['line-1'],
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('itemized_split_title')),
      'Market',
    );
    await _assignAllItems(tester);
    final submit = find.byKey(const Key('itemized_split_submit'));
    await _scrollTo(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    await tester.fling(
      find
          .descendant(
            of: find.byKey(const Key('itemized_split_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 1200),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 ürün henüz'), findsOneWidget);
    expect(find.textContaining('Organik tam buğday ekmeği'), findsWidgets);
    expect(
      find.text('Atanmayan ürünleri seçip tekrar deneyin.'),
      findsOneWidget,
    );
  });

  testWidgets('backend draft pozisyon hatasını OCR ürününe geri yansıtır', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      receipt: _draftReceipt,
      onSubmit: (_) async => throw const GroupApiException(
        statusCode: 422,
        error: GroupApiError(
          detail: GroupApiErrorDetail(
            code: 'unassigned_line_items',
            message: 'Atanmayan ürünler var.',
            unassignedReceiptLineItemPositions: [0],
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('itemized_split_title')),
      'Market',
    );
    final member = find.byKey(Key('itemized_line_0_member_$currentUserId'));
    await _scrollTo(tester, member);
    await tester.drag(
      find
          .descendant(
            of: find.byKey(const Key('itemized_split_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    await tester.tap(member);
    await tester.pump();

    final submit = find.byKey(const Key('itemized_split_submit'));
    await _scrollTo(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    await tester.fling(
      find
          .descendant(
            of: find.byKey(const Key('itemized_split_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 1200),
      2000,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 ürün henüz'), findsOneWidget);
    expect(find.textContaining('Süt'), findsWidgets);
    expect(
      find.text('Atanmayan ürünleri seçip tekrar deneyin.'),
      findsOneWidget,
    );
  });

  testWidgets('negatif farkta gönderimi engeller ve Fast Split geçişi sunar', (
    tester,
  ) async {
    var useFastSplitCalls = 0;

    const receipt = ItemizedSplitReceipt(
      receiptId: 'receipt',
      totalAmountInMinor: 5999,
      lineItems: [
        ItemizedReceiptLine(
          receiptLineItemId: 'line',
          name: 'Ürün',
          quantityMilli: 1000,
          unitPriceInMinor: 6000,
          totalAmountInMinor: 6000,
        ),
      ],
    );

    await _pumpPage(
      tester,
      receipt: receipt,
      onUseFastSplit: () {
        useFastSplitCalls++;
      },
    );

    final member = find.byKey(Key('itemized_line_0_member_$currentUserId'));
    await _scrollTo(tester, member);
    await tester.tap(member);
    await tester.pump();

    final warning = find.byKey(
      const Key('itemized_negative_difference_warning'),
    );
    await _scrollTo(tester, warning);

    expect(warning, findsOneWidget);

    final fastSplitButton = find.byKey(
      const Key('itemized_use_fast_split_button'),
    );
    await _scrollTo(tester, fastSplitButton);

    expect(fastSplitButton, findsOneWidget);

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('itemized_split_submit')))
          .onPressed,
      isNull,
    );

    await tester.tap(fastSplitButton);
    await tester.pump();

    expect(useFastSplitCalls, 1);
  });

  testWidgets('pasif üyeyi seçeneklerde göstermez', (tester) async {
    const group = GroupDetail(
      id: 'group',
      name: 'Grup',
      description: null,
      currency: 'TRY',
      memberCount: 1,
      currentUserRole: GroupRole.owner,
      createdBy: currentUserId,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
      archivedAt: null,
      members: [
        GroupMember(
          groupId: 'group',
          userId: currentUserId,
          displayName: 'Aktif Üye',
          role: GroupRole.owner,
          joinedAt: '2026-01-01T00:00:00Z',
          leftAt: null,
        ),
        GroupMember(
          groupId: 'group',
          userId: 'left-user',
          displayName: 'Ayrılmış Üye',
          role: GroupRole.member,
          joinedAt: '2026-01-01T00:00:00Z',
          leftAt: '2026-02-01T00:00:00Z',
        ),
      ],
    );
    await _pumpPage(tester, group: group);

    expect(find.text('Ayrılmış Üye'), findsNothing);
    expect(find.text('Aktif Üye'), findsWidgets);
  });

  testWidgets('boş ürün listesinde güvenli empty state gösterir', (
    tester,
  ) async {
    const emptyReceipt = ItemizedSplitReceipt(
      receiptId: 'receipt',
      totalAmountInMinor: 100,
      lineItems: [],
    );
    await _pumpPage(tester, receipt: emptyReceipt);

    expect(find.byKey(const Key('itemized_empty_state')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'küçük ekranda, uzun adlarda ve klavye açıkken taşma olmaz (${brightness.name})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        const longReceipt = ItemizedSplitReceipt(
          receiptId: 'receipt',
          totalAmountInMinor: 100,
          lineItems: [
            ItemizedReceiptLine(
              receiptLineItemId: 'line',
              name:
                  'Çok uzun isimli organik ve katkısız kahvaltılık ürün paketi',
              quantityMilli: 1000,
              unitPriceInMinor: 100,
              totalAmountInMinor: 100,
            ),
          ],
        );
        const longGroup = GroupDetail(
          id: 'group',
          name: 'Uzun Grup Adı',
          description: null,
          currency: 'TRY',
          memberCount: 1,
          currentUserRole: GroupRole.owner,
          createdBy: 'member',
          createdAt: '2026-01-01T00:00:00Z',
          updatedAt: '2026-01-01T00:00:00Z',
          archivedAt: null,
          members: [
            GroupMember(
              groupId: 'group',
              userId: 'member',
              displayName:
                  'Çok Uzun İsimli Bir Grup Üyesi ve Katılımcı Kullanıcı',
              role: GroupRole.owner,
              joinedAt: '2026-01-01T00:00:00Z',
              leftAt: null,
            ),
          ],
        );
        await _pumpPage(
          tester,
          receipt: longReceipt,
          group: longGroup,
          currentUser: 'member',
          brightness: brightness,
        );
        final member = find.byKey(const Key('itemized_line_0_member_member'));
        await _scrollTo(tester, member);
        await tester.tap(member);
        await tester.pump();
        final submit = find.byKey(const Key('itemized_split_submit'));
        await _scrollTo(tester, submit);
        await tester.pump();

        expect(submit, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  GroupDetail group = twoMemberGroup,
  ItemizedSplitReceipt receipt = _receipt,
  String currentUser = currentUserId,
  Brightness brightness = Brightness.light,
  ItemizedSplitSubmit? onSubmit,
  VoidCallback? onUseFastSplit,
}) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: brightness),
    home: ItemizedSplitPage(
      group: group,
      currentUserId: currentUser,
      receipt: receipt,
      onSubmit: onSubmit ?? (_) async {},
      onUseFastSplit: onUseFastSplit,
    ),
  ),
);

Future<void> _assignAllItems(WidgetTester tester) async {
  final first = find.byKey(Key('itemized_line_0_member_$currentUserId'));
  await _scrollTo(tester, first);
  await tester.tap(first);
  await tester.tap(find.byKey(Key('itemized_line_0_member_$secondUserId')));
  final last = find.byKey(Key('itemized_line_1_member_$secondUserId'));
  await _scrollTo(tester, last);
  await tester.tap(last);
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('itemized_split_scroll_view')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  if (finder.evaluate().isNotEmpty && tester.getCenter(finder).dy < 120) {
    await tester.drag(
      find
          .descendant(
            of: find.byKey(const Key('itemized_split_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 100),
    );
    await tester.pump();
  }
}
