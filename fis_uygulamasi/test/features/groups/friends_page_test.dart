import 'package:app_main/features/groups/data/fake_friend_repository.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/friend_models.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/activity_page.dart';
import 'package:app_main/features/groups/presentation/friends_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  Future<void> pumpFriendsPage(
    WidgetTester tester, {
    FakeFriendRepository? friendRepository,
    FakeGroupRepository? groupRepository,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        friendRepositoryProvider.overrideWithValue(
          friendRepository ?? FakeFriendRepository(),
        ),
        if (groupRepository != null)
          groupRepositoryProvider.overrideWithValue(groupRepository),
      ],
      child: const MaterialApp(home: FriendsPage()),
    ),
  );

  testWidgets('AppBar arama ve kişi ekleme ikonlarını gösterir', (
    tester,
  ) async {
    await pumpFriendsPage(tester);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsWidgets);
  });

  testWidgets('genel bakiye metni ve filtre ikonu gösterilir', (tester) async {
    await pumpFriendsPage(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Genel bakiye'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('arkadaş listesinde avatar, isim ve bakiye durumu gösterilir', (
    tester,
  ) async {
    await pumpFriendsPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Ege Başaran'), findsOneWidget);
    expect(find.textContaining('borçlusunuz'), findsWidgets);
    expect(find.textContaining('alacaklısınız'), findsWidgets);
  });

  testWidgets('daha fazla arkadaş ekle butonu ve harcama ekle FAB görünür', (
    tester,
  ) async {
    await pumpFriendsPage(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_more_friends_button')), findsOneWidget);
    expect(find.text('Daha fazla arkadaş ekle'), findsOneWidget);
    expect(find.byKey(const Key('add_friend_expense_button')), findsOneWidget);
    expect(find.text('Harcama ekle'), findsOneWidget);
  });

  testWidgets('arkadaş ekle daveti gönderir', (tester) async {
    await pumpFriendsPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_more_friends_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('friend_invitation_email_field')),
      'arkadas@example.com',
    );
    await tester.tap(find.byKey(const Key('submit_friend_invitation_button')));
    await tester.pumpAndSettle();

    expect(find.text('Arkadaşlık daveti gönderildi.'), findsOneWidget);
  });

  testWidgets('bekleyen arkadaşlık daveti gösterilir ve kabul edilebilir', (
    tester,
  ) async {
    final friendRepository = FakeFriendRepository(
      friends: const [],
      pendingInvitations: const [
        PendingFriendInvitation(
          id: 'friend-invite-1',
          inviterDisplayName: 'Ege Başaran',
          createdAt: '2026-08-21T10:00:00Z',
          expiresAt: '2026-08-22T10:00:00Z',
        ),
      ],
    );
    await pumpFriendsPage(tester, friendRepository: friendRepository);
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen davetler'), findsOneWidget);
    expect(find.textContaining('Ege Başaran'), findsOneWidget);
    expect(
      find.textContaining('seni arkadaş olarak eklemek istiyor'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('accept_friend_invitation_friend-invite-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arkadaşlık daveti kabul edildi.'), findsOneWidget);
    expect(find.text('Bekleyen davetler'), findsNothing);
  });

  testWidgets('bekleyen grup daveti gösterilir ve kabul edilebilir', (
    tester,
  ) async {
    final groupRepository = FakeGroupRepository(
      groups: const <GroupDetail>[twoMemberGroup],
      pendingGroupInvitations: const [
        PendingGroupInvitation(
          id: 'group-invite-1',
          groupId: twoMemberGroupId,
          groupName: 'Ev Arkadaşları',
          role: 'member',
          inviterDisplayName: 'Zafer Tuna',
          createdAt: '2026-08-21T10:00:00Z',
          expiresAt: '2026-08-22T10:00:00Z',
        ),
      ],
    );
    await pumpFriendsPage(tester, groupRepository: groupRepository);
    await tester.pumpAndSettle();

    expect(find.text('Bekleyen davetler'), findsOneWidget);
    expect(find.textContaining('Ev Arkadaşları'), findsOneWidget);
    expect(find.textContaining('grubuna davet etti'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('accept_group_invitation_group-invite-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ev Arkadaşları grubuna katıldınız.'),
      findsOneWidget,
    );
    expect(find.text('Bekleyen davetler'), findsNothing);
  });

  testWidgets('alt navigasyonda Arkadaşlar sekmesi aktif gösterilir', (
    tester,
  ) async {
    await pumpFriendsPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('Arkadaşlar'), findsOneWidget);
    expect(find.text('Gruplar'), findsOneWidget);
    expect(find.text('Hareketler'), findsOneWidget);
    expect(find.text('Hesap'), findsOneWidget);
  });

  testWidgets(
    'alt navigasyonda Gruplar sekmesine basınca önceki ekrana dönülür',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/groups',
        routes: [
          GoRoute(
            path: '/groups',
            builder: (_, _) =>
                const Scaffold(body: Center(child: Text('groups placeholder'))),
          ),
          GoRoute(path: '/friends', builder: (_, _) => const FriendsPage()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            friendRepositoryProvider.overrideWithValue(FakeFriendRepository()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.push('/friends');
      await tester.pumpAndSettle();
      expect(find.byType(FriendsPage), findsOneWidget);

      await tester.tap(find.text('Gruplar'));
      await tester.pumpAndSettle();

      expect(find.text('groups placeholder'), findsOneWidget);
      expect(find.byType(FriendsPage), findsNothing);
    },
  );

  testWidgets('alt navigasyondan Hareketler ekranı açılır', (tester) async {
    final router = GoRouter(
      initialLocation: '/friends',
      routes: [
        GoRoute(path: '/friends', builder: (_, _) => const FriendsPage()),
        GoRoute(
          path: '/activity',
          builder: (_, _) => const ActivityPage(activities: []),
        ),
        GoRoute(path: '/groups', builder: (_, _) => const Text('groups page')),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Text('profile page'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendRepositoryProvider.overrideWithValue(FakeFriendRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hareketler'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityPage), findsOneWidget);
    expect(find.text('Son hareketler'), findsOneWidget);
  });
}
