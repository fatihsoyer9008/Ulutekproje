import 'package:app_main/features/avatar/presentation/widgets/avatar_badge.dart';
import 'package:app_main/features/groups/data/group_activity_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_activity_models.dart';
import 'package:app_main/features/groups/presentation/activity_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  final now = DateTime(2026, 8, 21, 15, 0);

  testWidgets('başlık, arama ikonu ve harcama ekle FAB görünür', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      now: now,
      activities: [_entry(id: 'header', subject: 'Elektrik', occurredAt: now)],
    );

    expect(find.text('Son hareketler'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(
      find.byKey(const Key('add_activity_expense_button')),
      findsOneWidget,
    );
    expect(find.text('Harcama ekle'), findsOneWidget);
  });

  testWidgets('hareketleri en yeniden eskiye doğru sıralar', (tester) async {
    final older = _entry(
      id: 'older',
      subject: 'Eski hareket',
      occurredAt: now.subtract(const Duration(days: 5)),
    );
    final newer = _entry(
      id: 'newer',
      subject: 'Yeni hareket',
      occurredAt: now.subtract(const Duration(days: 1)),
    );

    await _pumpPage(tester, now: now, activities: [older, newer]);

    final newerTop = tester.getTopLeft(find.byKey(const Key('activity_newer')));
    final olderTop = tester.getTopLeft(find.byKey(const Key('activity_older')));
    expect(newerTop.dy, lessThan(olderTop.dy));
  });

  testWidgets('işlem metni, finansal sonuç ve göreli tarih gösterilir', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      now: now,
      activities: [
        _entry(
          id: 'electricity',
          subject: 'Elektrik',
          occurredAt: now.subtract(const Duration(days: 2)),
          balanceEffect: GroupActivityBalanceEffect.receivable,
          amountInMinor: 15350,
        ),
      ],
    );

    expect(find.textContaining('ekledi'), findsOneWidget);
    expect(find.textContaining('Elektrik'), findsOneWidget);
    expect(find.text('TL153,50 alacaksınız'), findsOneWidget);
    expect(find.textContaining('2 gün önce'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsWidgets);
    expect(find.byType(AvatarBadge), findsOneWidget);
  });

  testWidgets('borç ve nötr hareket durumlarını ayırt eder', (tester) async {
    await _pumpPage(
      tester,
      now: now,
      activities: [
        _entry(
          id: 'payable',
          subject: 'Doğalgaz',
          occurredAt: now.subtract(const Duration(days: 1)),
          balanceEffect: GroupActivityBalanceEffect.payable,
          amountInMinor: 4000,
        ),
        _entry(
          id: 'neutral',
          subject: 'Grup',
          occurredAt: now.subtract(const Duration(days: 2)),
          type: GroupActivityType.groupCreated,
          balanceEffect: GroupActivityBalanceEffect.neutral,
        ),
      ],
    );

    expect(find.text('TL40,00 borcunuz var'), findsOneWidget);
    expect(find.text('Borcunuz yok'), findsOneWidget);
    expect(find.byType(AvatarBadge), findsNWidgets(2));
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
  });

  testWidgets('boş hareket listesinde empty state gösterilir', (tester) async {
    await _pumpPage(tester, now: now, activities: const []);

    expect(find.text('Henüz hareket yok'), findsOneWidget);
    expect(
      find.text('Grup harcamaları ve ödemeler burada görünecek.'),
      findsOneWidget,
    );
  });

  testWidgets('API hatasında güvenli mesaj gösterir ve tekrar dener', (
    tester,
  ) async {
    final repository = _RetryActivityRepository(
      successEntry: _entry(id: 'retried', subject: 'İnternet', occurredAt: now),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupActivityRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(home: ActivityPage(referenceTime: now)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hareketler yüklenemedi'), findsOneWidget);
    expect(
      find.text(
        'Hareketler yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('activity_retry_button')));
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Son hareketler'), findsOneWidget);
    expect(find.textContaining('İnternet'), findsOneWidget);
  });

  testWidgets('alt navigasyon Groups ve Friends rotalarına gider', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/activity',
      routes: [
        GoRoute(
          path: '/activity',
          builder: (_, _) =>
              ActivityPage(activities: const [], referenceTime: now),
        ),
        GoRoute(path: '/groups', builder: (_, _) => const Text('groups page')),
        GoRoute(
          path: '/friends',
          builder: (_, _) => const Text('friends page'),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Text('profile page'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hareketler'), findsOneWidget);
    await tester.tap(find.text('Arkadaşlar'));
    await tester.pumpAndSettle();
    expect(find.text('friends page'), findsOneWidget);

    router.go('/activity');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gruplar'));
    await tester.pumpAndSettle();
    expect(find.text('groups page'), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required DateTime now,
  List<GroupActivityEntry>? activities,
}) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp(
      home: ActivityPage(activities: activities, referenceTime: now),
    ),
  ),
);

GroupActivityEntry _entry({
  required String id,
  required String subject,
  required DateTime occurredAt,
  GroupActivityType type = GroupActivityType.expenseAdded,
  GroupActivityBalanceEffect balanceEffect = GroupActivityBalanceEffect.neutral,
  int amountInMinor = 0,
}) => GroupActivityEntry(
  id: id,
  type: type,
  actorName: 'You',
  actorAvatarId: 'woman',
  isCurrentUserActor: true,
  subject: subject,
  groupName: 'Bursa',
  occurredAt: occurredAt,
  balanceEffect: balanceEffect,
  amountInMinor: amountInMinor,
  currency: 'TRY',
);

class _RetryActivityRepository implements GroupActivityRepository {
  _RetryActivityRepository({required this.successEntry});

  final GroupActivityEntry successEntry;
  int calls = 0;

  @override
  Future<GroupActivityPage> listActivity({
    int limit = 50,
    String? before,
  }) async {
    calls++;
    if (calls == 1) throw StateError('internal activity database error');
    return GroupActivityPage(items: [successEntry], nextCursor: null);
  }
}
