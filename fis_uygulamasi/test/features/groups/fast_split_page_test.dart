import 'package:app_main/features/groups/presentation/fast_split_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('ödeyen ve katılımcı seçimiyle eşit bölüşümü kaydeder', (
    tester,
  ) async {
    FastSplitFormValue? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: FastSplitPage(
          group: twoMemberGroup,
          currentUserId: currentUserId,
          onSubmit: (value) async => submitted = value,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('fast_split_title')), 'Market');
    await tester.enterText(find.byKey(const Key('fast_split_total')), '100,01');
    await tester.tap(find.byKey(const Key('fast_split_submit')));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.payerUserId, currentUserId);
    expect(
      submitted!.calculation.shares.map((share) => share.amountInMinor),
      orderedEquals([5001, 5000]),
    );
  });

  testWidgets('tutar payları ana tutarla eşleşmiyorsa uyarı gösterir', (
    tester,
  ) async {
    FastSplitFormValue? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: FastSplitPage(
          group: twoMemberGroup,
          currentUserId: currentUserId,
          onSubmit: (value) async => submitted = value,
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('fast_split_title')), 'Market');
    await tester.enterText(find.byKey(const Key('fast_split_total')), '100');
    await tester.tap(find.text('Tutar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('share_$currentUserId')), '40');
    await tester.enterText(find.byKey(Key('share_$secondUserId')), '59,99');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fast_split_submit')));
    await tester.pump();

    expect(submitted, isNull);
    expect(find.text('Pay toplamı ana tutarla eşleşmelidir.'), findsOneWidget);
    expect(find.textContaining('0.01'), findsOneWidget);
  });
}
