import 'package:app_main/features/groups/presentation/fast_split_page.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
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

  testWidgets('yüzdelik bölüşümü başarıyla gönderir', (tester) async {
    FastSplitFormValue? submitted;
    await _pumpPage(tester, onSubmit: (value) async => submitted = value);
    await _fillCommonFields(tester);
    await tester.tap(find.text('Yüzde'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('share_$currentUserId')), '60');
    await tester.enterText(find.byKey(Key('share_$secondUserId')), '40');
    await _submit(tester);

    expect(submitted, isNotNull);
    expect(submitted!.percentageBasisPoints, {
      currentUserId: 6000,
      secondUserId: 4000,
    });
    expect(submitted!.calculation.isBalanced, isTrue);
  });

  testWidgets('tutar bazlı bölüşümü başarıyla gönderir', (tester) async {
    FastSplitFormValue? submitted;
    await _pumpPage(tester, onSubmit: (value) async => submitted = value);
    await _fillCommonFields(tester);
    await tester.tap(find.text('Tutar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('share_$currentUserId')), '40');
    await tester.enterText(find.byKey(Key('share_$secondUserId')), '60');
    await _submit(tester);

    expect(submitted, isNotNull);
    expect(
      submitted!.calculation.shares.map((share) => share.amountInMinor),
      orderedEquals([4000, 6000]),
    );
  });

  testWidgets('ödeyen kullanıcı değiştirilebilir', (tester) async {
    FastSplitFormValue? submitted;
    await _pumpPage(tester, onSubmit: (value) async => submitted = value);
    await _fillCommonFields(tester);
    await tester.tap(find.byKey(const Key('fast_split_payer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abdullah Seydi').last);
    await tester.pumpAndSettle();
    await _submit(tester);

    expect(submitted!.payerUserId, secondUserId);
  });

  testWidgets('katılımcı kaldırılıp yeniden eklenebilir', (tester) async {
    FastSplitFormValue? submitted;
    await _pumpPage(tester, onSubmit: (value) async => submitted = value);
    await _fillCommonFields(tester);
    final participant = find.byKey(Key('participant_$secondUserId'));
    await tester.tap(participant);
    await tester.pump();
    await tester.tap(participant);
    await tester.pump();
    await _submit(tester);

    expect(submitted!.calculation.shares, hasLength(2));
  });

  testWidgets('yöntem değişiminde eski değerler yeni yönteme taşınmaz', (
    tester,
  ) async {
    await _pumpPage(tester, onSubmit: (_) async {});
    await _fillCommonFields(tester);
    await tester.tap(find.text('Yüzde'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('share_$currentUserId')), '75');

    await tester.tap(find.text('Tutar'));
    await tester.pumpAndSettle();
    final fixedField = tester.widget<TextFormField>(
      find.byKey(Key('share_$currentUserId')),
    );
    expect(fixedField.controller!.text, isEmpty);

    await tester.tap(find.text('Yüzde'));
    await tester.pumpAndSettle();
    final percentageField = tester.widget<TextFormField>(
      find.byKey(Key('share_$currentUserId')),
    );
    expect(percentageField.controller!.text, '75');
  });

  testWidgets('aktif katılımcı yoksa ekran çökmez', (tester) async {
    const emptyGroup = GroupDetail(
      id: 'empty',
      name: 'Boş Grup',
      description: null,
      currency: 'TRY',
      memberCount: 0,
      currentUserRole: GroupRole.owner,
      createdBy: currentUserId,
      createdAt: '2026-08-11T00:00:00Z',
      updatedAt: '2026-08-11T00:00:00Z',
      archivedAt: null,
      members: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FastSplitPage(
          group: emptyGroup,
          currentUserId: currentUserId,
          onSubmit: (_) async {},
        ),
      ),
    );

    expect(find.text('Boş Grup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required FastSplitSubmit onSubmit,
}) => tester.pumpWidget(
  MaterialApp(
    home: FastSplitPage(
      group: twoMemberGroup,
      currentUserId: currentUserId,
      onSubmit: onSubmit,
    ),
  ),
);

Future<void> _fillCommonFields(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('fast_split_title')), 'Market');
  await tester.enterText(find.byKey(const Key('fast_split_total')), '100');
}

Future<void> _submit(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('fast_split_submit')));
  await tester.pumpAndSettle();
}
