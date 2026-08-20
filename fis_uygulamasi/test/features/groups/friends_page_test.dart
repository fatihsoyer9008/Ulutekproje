import 'package:app_main/features/groups/presentation/friends_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('AppBar arama ve kişi ekleme ikonlarını gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FriendsPage()));

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsWidgets);
  });

  testWidgets('genel bakiye metni ve filtre ikonu gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FriendsPage()));

    expect(find.textContaining('Genel bakiye'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('arkadaş listesinde avatar, isim ve bakiye durumu gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FriendsPage()));

    expect(find.text('Ege Başaran'), findsOneWidget);
    expect(find.textContaining('borçlusunuz'), findsWidgets);
    expect(find.textContaining('alacaklısınız'), findsWidgets);
  });

  testWidgets('daha fazla arkadaş ekle butonu ve harcama ekle FAB görünür', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FriendsPage()));

    expect(find.byKey(const Key('add_more_friends_button')), findsOneWidget);
    expect(find.text('Daha fazla arkadaş ekle'), findsOneWidget);
    expect(find.byKey(const Key('add_friend_expense_button')), findsOneWidget);
    expect(find.text('Harcama ekle'), findsOneWidget);
  });

  testWidgets('alt navigasyonda Arkadaşlar sekmesi aktif gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FriendsPage()));

    expect(find.text('Arkadaşlar'), findsOneWidget);
    expect(find.text('Gruplar'), findsOneWidget);
    expect(find.text('Hareketler'), findsOneWidget);
    expect(find.text('Hesap'), findsOneWidget);
  });

  testWidgets('alt navigasyonda Gruplar sekmesine basınca önceki ekrana dönülür', (
    tester,
  ) async {
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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.push('/friends');
    await tester.pumpAndSettle();
    expect(find.byType(FriendsPage), findsOneWidget);

    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();

    expect(find.text('groups placeholder'), findsOneWidget);
    expect(find.byType(FriendsPage), findsNothing);
  });
}
