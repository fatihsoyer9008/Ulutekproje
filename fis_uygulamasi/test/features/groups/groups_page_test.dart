import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/application/itemized_split_calculator.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/groups_page.dart';
import 'package:app_main/features/groups/presentation/fast_split_page.dart';
import 'package:app_main/features/groups/presentation/itemized_split_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('grup kartında ad, üye sayısı ve borç durumu gösterilir', (
    tester,
  ) async {
    final repository = FakeGroupRepository(
      groups: const [twoMemberGroup],
      debtSummariesByGroup: const {
        twoMemberGroupId: currentUserDebtorDebtSummary,
      },
    );

    await _pumpGroupsPage(tester, repository);

    expect(find.text('Ev Arkadaşları'), findsOneWidget);
    expect(find.text('2 üye'), findsOneWidget);
    expect(find.textContaining('borç'), findsOneWidget);
  });

  testWidgets('alacaklı kullanıcının net durumu gösterilir', (tester) async {
    final repository = FakeGroupRepository(
      groups: const [twoMemberGroup],
      debtSummariesByGroup: const {
        twoMemberGroupId: currentUserCreditorDebtSummary,
      },
    );

    await _pumpGroupsPage(tester, repository);

    expect(find.textContaining('alacak'), findsOneWidget);
  });

  testWidgets('grup kartı mevcut Fast Split akışını açar', (tester) async {
    final repository = FakeGroupRepository(groups: const [twoMemberGroup]);
    await _pumpGroupsPage(tester, repository);

    await tester.tap(find.byKey(Key('group_card_$twoMemberGroupId')));
    await tester.pumpAndSettle();

    expect(find.byType(FastSplitPage), findsOneWidget);
  });

  testWidgets('cloud fişi grup akışından kalem bazlı ekrana taşır', (
    tester,
  ) async {
    final repository = FakeGroupRepository(groups: const [twoMemberGroup]);
    const receipt = ItemizedSplitReceipt(
      receiptId: '20000000-0000-4000-8000-000000000001',
      totalAmountInMinor: 1000,
      lineItems: [
        ItemizedReceiptLine(
          receiptLineItemId: '30000000-0000-4000-8000-000000000001',
          name: 'Süt',
          quantityMilli: 1000,
          unitPriceInMinor: 1000,
          totalAmountInMinor: 1000,
        ),
      ],
    );
    await _pumpGroupsPage(tester, repository, itemizedReceipt: receipt);

    await tester.tap(find.byKey(Key('group_card_$twoMemberGroupId')));
    await tester.pumpAndSettle();
    final itemizedButton = find.byKey(const Key('open_itemized_split'));
    await tester.scrollUntilVisible(
      itemizedButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(itemizedButton);
    await tester.pumpAndSettle();

    expect(find.byType(ItemizedSplitPage), findsOneWidget);
  });

  testWidgets('net tutar sıfırsa dengede durumu gösterilir', (tester) async {
    const balancedSummary = DebtSummary(
      groupId: twoMemberGroupId,
      currency: 'TRY',
      balances: [
        DebtBalance(
          userId: currentUserId,
          displayName: 'Zafer Tuna',
          netAmountInMinor: 0,
        ),
      ],
      suggestedTransfers: [],
      generatedAt: '2026-08-11T09:05:00Z',
    );

    final repository = FakeGroupRepository(
      groups: const [twoMemberGroup],
      debtSummariesByGroup: const {twoMemberGroupId: balancedSummary},
    );

    await _pumpGroupsPage(tester, repository);

    expect(find.text('Dengede'), findsOneWidget);
  });

  testWidgets('grup yoksa empty state gösterilir', (tester) async {
    await _pumpGroupsPage(tester, FakeGroupRepository());

    expect(find.text('Henüz grubunuz yok'), findsOneWidget);
    expect(find.byKey(const Key('create_group_button')), findsOneWidget);
  });

  testWidgets('yükleme sırasında progress göstergesi gösterilir', (
    tester,
  ) async {
    final repository = FakeGroupRepository(
      latency: const Duration(milliseconds: 100),
    );

    final controller = AuthSessionController(_GroupsAuthRepository());
    await controller.login('user@example.com', 'password');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith((ref) => controller),
          groupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: GroupsPage()),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });

  testWidgets('debt summary yüklenirken net durum metni gösterilir', (
    tester,
  ) async {
    final repository = FakeGroupRepository(groups: const [twoMemberGroup]);

    await _pumpGroupsPage(
      tester,
      repository,
      debtSummaryRepository: _DelayedDebtSummaryRepository(
        summary: currentUserDebtorDebtSummary,
      ),
      settle: false,
    );
    await tester.pump();

    expect(find.text('Hesaplanıyor…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });

  testWidgets('gruplar yüklenemezse hata durumu gösterilir', (tester) async {
    await _pumpGroupsPage(
      tester,
      FakeGroupRepository(error: groupsApiErrorException),
    );

    expect(find.text('Gruplar yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  testWidgets('Tekrar dene listeyi yeniden yükler', (tester) async {
    final repository = _RetryingGroupRepository(groups: const [twoMemberGroup]);

    await _pumpGroupsPage(tester, repository);

    expect(find.text('Gruplar yüklenemedi'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(find.text('Ev Arkadaşları'), findsOneWidget);
  });

  testWidgets('debt summary hatası net durum alanında gösterilir', (
    tester,
  ) async {
    await _pumpGroupsPage(
      tester,
      FakeGroupRepository(groups: const [twoMemberGroup]),
      debtSummaryRepository: const _FailingDebtSummaryRepository(),
    );

    expect(find.text('Alınamadı'), findsOneWidget);
  });

  testWidgets('boş grup adı için validasyon gösterilir', (tester) async {
    await _pumpGroupsPage(tester, FakeGroupRepository());

    await tester.tap(find.byKey(const Key('create_group_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create_group_submit_button')));
    await tester.pump();

    expect(find.text('Grup adı boş bırakılamaz.'), findsOneWidget);
  });

  testWidgets('grup oluşturma hatası kullanıcıya gösterilir', (tester) async {
    await _pumpGroupsPage(tester, _CreateFailingGroupRepository());

    await tester.tap(find.byKey(const Key('create_group_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('group_name_field')),
      'Başarısız Grup',
    );
    await tester.tap(find.byKey(const Key('create_group_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Grup bilgileri şu anda alınamıyor.'), findsOneWidget);
  });

  testWidgets('yeni grup oluşturulunca liste yenilenir', (tester) async {
    await _pumpGroupsPage(tester, FakeGroupRepository());

    await tester.tap(find.byKey(const Key('create_group_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('group_name_field')),
      'Hafta Sonu Planı',
    );
    await tester.tap(find.byKey(const Key('create_group_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Hafta Sonu Planı'), findsOneWidget);
    expect(find.text('Grup oluşturuldu.'), findsOneWidget);
  });
}

Future<void> _pumpGroupsPage(
  WidgetTester tester,
  FakeGroupRepository repository, {
  DebtSummaryRepository? debtSummaryRepository,
  ItemizedSplitReceipt? itemizedReceipt,
  bool settle = true,
}) async {
  final controller = AuthSessionController(_GroupsAuthRepository());
  await controller.login('user@example.com', 'password');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => controller),
        groupRepositoryProvider.overrideWithValue(repository),
        if (itemizedReceipt != null)
          latestItemizedReceiptProvider.overrideWith(
            (ref) async => itemizedReceipt,
          ),
        if (debtSummaryRepository != null)
          debtSummaryRepositoryProvider.overrideWithValue(
            debtSummaryRepository,
          ),
      ],
      child: const MaterialApp(home: GroupsPage()),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  }
}

class _RetryingGroupRepository extends FakeGroupRepository {
  _RetryingGroupRepository({required super.groups});

  bool _shouldFail = true;

  @override
  Future<GroupsResponse> listGroups({bool includeArchived = false}) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw groupsApiErrorException;
    }

    return super.listGroups(includeArchived: includeArchived);
  }
}

class _CreateFailingGroupRepository extends FakeGroupRepository {
  @override
  Future<GroupDetail> createGroup({
    required String name,
    String? description,
    String currency = 'TRY',
  }) async {
    throw groupsApiErrorException;
  }
}

class _DelayedDebtSummaryRepository implements DebtSummaryRepository {
  const _DelayedDebtSummaryRepository({required this.summary});

  final DebtSummary summary;

  @override
  Future<DebtSummary> getDebtSummary(String groupId) {
    return Future<DebtSummary>.delayed(
      const Duration(milliseconds: 100),
      () => summary,
    );
  }
}

class _FailingDebtSummaryRepository implements DebtSummaryRepository {
  const _FailingDebtSummaryRepository();

  @override
  Future<DebtSummary> getDebtSummary(String groupId) async {
    throw groupsApiErrorException;
  }
}

class _GroupsAuthRepository implements AuthRepositoryBase {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    return const AuthUser(
      id: currentUserId,
      email: 'user@example.com',
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() {
    return login(email: 'google@example.com', password: 'unused');
  }

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> silentRefresh() async => null;

  @override
  Future<void> deleteAccount({String? currentPassword}) async {}

  @override
  Future<String> forgotPassword(String email) async => 'Sent';

  @override
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) async => 'Registered';

  @override
  Future<String> resendVerification(String email) async => 'Sent';

  @override
  Future<String> verifyEmail(String token) async => 'Verified';
}
