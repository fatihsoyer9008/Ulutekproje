import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/presentation/pages/group_detail_page.dart';
import 'package:app_main/features/groups/presentation/pages/create_group_page.dart';
import 'package:app_main/features/groups/presentation/pages/groups_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  testWidgets('boş grup listesi empty state gösterir', (tester) async {
    await _pump(tester, const GroupsPage(), FakeGroupRepository());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('groups_empty')), findsOneWidget);
  });

  testWidgets('iki ve dört üyeli grup kartlarını gösterir', (tester) async {
    await _pump(
      tester,
      const GroupsPage(),
      FakeGroupRepository(groups: const [twoMemberGroup, fourMemberGroup]),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 üye'), findsOneWidget);
    expect(find.text('4 üye'), findsOneWidget);
  });

  testWidgets('repository hatası ve tekrar deneme aksiyonu gösterir', (
    tester,
  ) async {
    await _pump(
      tester,
      const GroupsPage(),
      FakeGroupRepository(error: groupsApiErrorException),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('groups_error')), findsOneWidget);
    expect(find.byKey(const Key('groups_retry_button')), findsOneWidget);
  });

  testWidgets('grup kartı borçlu ve alacaklı net durumunu gösterir', (
    tester,
  ) async {
    await _pump(
      tester,
      const GroupsPage(),
      FakeGroupRepository(
        groups: const [twoMemberGroup],
        debtSummariesByGroup: const {
          twoMemberGroupId: currentUserDebtorDebtSummary,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('borcun var'), findsOneWidget);

    await _pump(
      tester,
      const GroupsPage(),
      FakeGroupRepository(
        groups: const [twoMemberGroup],
        debtSummariesByGroup: const {
          twoMemberGroupId: currentUserCreditorDebtSummary,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('alacağın var'), findsOneWidget);
  });

  testWidgets('grup adı yalnız boşluk olduğunda formu göndermez', (
    tester,
  ) async {
    await _pump(tester, const CreateGroupPage(), FakeGroupRepository());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('group_name_field')), '   ');
    await tester.tap(find.byKey(const Key('submit_group_button')));
    await tester.pump();
    expect(find.text('Grup adı boş bırakılamaz.'), findsOneWidget);
  });

  testWidgets('detayda üç sekme ve boş masraf durumu bulunur', (tester) async {
    await _pump(
      tester,
      const GroupDetailPage(groupId: twoMemberGroupId),
      FakeGroupRepository(groups: const [twoMemberGroup]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Masraflar'), findsOneWidget);
    expect(find.text('Borç Özeti'), findsOneWidget);
    expect(find.text('Üyeler'), findsOneWidget);
    expect(find.byKey(const Key('expenses_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('debts_tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debts_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('members_tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('members_list')), findsOneWidget);
  });

  testWidgets('küçük ekranda koyu tema ve grup semantiği taşma yapmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(
            FakeGroupRepository(groups: const [twoMemberGroup]),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const GroupsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Ev Arkadaşları, 2 üye'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  GroupRepository repository,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [groupRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: child),
    ),
  );
}
