import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/group_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('grup detayı başlık, masraflar ve üyeleri gösterir', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        expensesByGroup: const {
          twoMemberGroupId: [fastSplitTransferExpense],
        },
      ),
    );

    expect(find.byKey(const Key('group_detail_name')), findsOneWidget);
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
    expect(find.text('2 üye'), findsOneWidget);
    expect(find.text('Masraflar'), findsOneWidget);
    expect(find.text('Borç Özeti'), findsOneWidget);

    expect(find.text('Aylık market alışverişi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('add_group_member_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Üyeler'), findsOneWidget);
    expect(find.text('Zafer Tuna'), findsOneWidget);
    expect(find.text('Abdullah Seydi'), findsOneWidget);
    expect(find.byKey(const Key('group_role_owner')), findsWidgets);
    expect(find.byKey(const Key('group_role_member')), findsWidgets);
  });

  testWidgets('owner üye ekleme ve member çıkarma aksiyonlarını görür', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('add_group_member_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('add_group_member_button')), findsOneWidget);
    expect(
      find.byKey(Key('remove_group_member_$secondUserId')),
      findsOneWidget,
    );
    expect(find.byKey(Key('remove_group_member_$currentUserId')), findsNothing);
  });

  testWidgets('member kullanıcı üye yönetim aksiyonlarını görmez', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        currentUserId: secondUserId,
        groups: const <GroupDetail>[twoMemberGroup],
      ),
      userId: secondUserId,
    );

    expect(find.byKey(const Key('add_group_member_button')), findsNothing);
    expect(find.byKey(Key('remove_group_member_$currentUserId')), findsNothing);
    expect(find.byKey(Key('remove_group_member_$secondUserId')), findsNothing);
  });

  testWidgets('owner grup daveti gönderebilir', (tester) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('add_group_member_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('add_group_member_button')));
    await tester.pumpAndSettle();

    expect(find.text('Gruba Davet Et'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('group_invitation_email_field')),
      'yeni.uye@example.com',
    );
    await tester.tap(find.byKey(const Key('submit_group_invitation_button')));
    await tester.pumpAndSettle();

    expect(find.text('Grup daveti gönderildi.'), findsOneWidget);
  });
  testWidgets(
    'Fast Split kaydından sonra detay ekranındaki masraf listesi yenilenir',
    (tester) async {
      await _pumpDetailPage(
        tester,
        repository: FakeGroupRepository(
          groups: const <GroupDetail>[twoMemberGroup],
        ),
      );

      await tester.tap(find.byKey(const Key('add_group_expense_button')));
      await tester.pumpAndSettle();

      expect(find.text('Bölüştürme Türünü Seç'), findsOneWidget);

      await tester.tap(find.byKey(const Key('select_fast_split_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hızlı Bölüştürme'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('fast_split_title')),
        'Haftalık market',
      );
      await tester.enterText(
        find.byKey(const Key('fast_split_total')),
        '120,00',
      );

      await tester.tap(find.byKey(const Key('fast_split_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Haftalık market'), findsOneWidget);
      expect(find.text('Masraf kaydedildi.'), findsOneWidget);
    },
  );

  testWidgets('yeni masraf için bölüştürme türü seçenekleri gösterilir', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    await tester.tap(find.byKey(const Key('add_group_expense_button')));
    await tester.pumpAndSettle();

    expect(find.text('Bölüştürme Türünü Seç'), findsOneWidget);
    expect(find.byKey(const Key('select_fast_split_button')), findsOneWidget);
    expect(
      find.byKey(const Key('select_itemized_split_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('select_itemized_split_button')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Kalem bazlı bölüştürme için önce'),
      findsOneWidget,
    );
  });

  testWidgets('owner üye çıkarma işlemini onaylayabilir', (tester) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(Key('remove_group_member_$secondUserId')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(Key('remove_group_member_$secondUserId')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('remove_member_confirmation_dialog')),
      findsOneWidget,
    );
    expect(find.text('Üyeyi çıkar'), findsWidgets);

    await tester.tap(find.byKey(const Key('confirm_remove_member_button')));
    await tester.pumpAndSettle();

    expect(find.text('Abdullah Seydi'), findsNothing);

    expect(find.text('Üye gruptan çıkarıldı.'), findsOneWidget);
  });

  testWidgets('detay hata ekranındaki tekrar dene veriyi yeniden yükler', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: _RetryingDetailRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    expect(find.byKey(const Key('group_detail_retry_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group_detail_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_detail_name')), findsOneWidget);
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
  });

  testWidgets('grup detayı yüklenirken progress göstergesi gösterilir', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        latency: const Duration(milliseconds: 100),
      ),
      settle: false,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  });

  testWidgets('admin üye yönetim aksiyonlarını görür', (tester) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        currentUserId: feyzaUserId,
        groups: const <GroupDetail>[fourMemberGroup],
      ),
      userId: feyzaUserId,
      groupId: fourMemberGroupId,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('add_group_member_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('group_role_admin')), findsWidgets);
    expect(find.byKey(const Key('add_group_member_button')), findsOneWidget);

    expect(find.byKey(Key('remove_group_member_$mineUserId')), findsOneWidget);
    expect(find.byKey(Key('remove_group_member_$feyzaUserId')), findsNothing);
    expect(find.byKey(Key('remove_group_member_$currentUserId')), findsNothing);
  });

  testWidgets('masraf yokken empty state gösterilir', (tester) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    expect(find.text('Henüz masraf yok'), findsOneWidget);
  });

  testWidgets('grup detayı hata aldığında tekrar dene gösterilir', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        error: groupsApiErrorException,
      ),
    );

    expect(find.text('Grup detayı yüklenemedi'), findsOneWidget);
    expect(find.byKey(const Key('group_detail_retry_button')), findsOneWidget);
  });

  testWidgets('ödeme yapıldıktan sonra borç özeti yenilenir', (tester) async {
    final repository = FakeGroupRepository(
      currentUserId: secondUserId,
      groups: const <GroupDetail>[twoMemberGroup],
      debtSummariesByGroup: const <String, DebtSummary>{
        twoMemberGroupId: currentUserCreditorDebtSummary,
      },
    );

    await _pumpDetailPage(tester, repository: repository, userId: secondUserId);

    await tester.scrollUntilVisible(
      find.byKey(const Key('open_debt_summary_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('open_debt_summary_button')));
    await tester.pumpAndSettle();

    final transferKey = '$secondUserId-$currentUserId';
    final markPaidButton = find.byKey(Key('mark_paid_$transferKey'));

    expect(markPaidButton, findsOneWidget);

    await tester.tap(markPaidButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settlement_confirmation_dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('confirm_settlement')));
    await tester.pumpAndSettle();

    expect(find.text('Tüm borçlar kapatılmış görünüyor.'), findsOneWidget);
    expect(markPaidButton, findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_detail_name')), findsOneWidget);
    expect(find.text('Ev Arkadaşları'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_debt_summary_button')));
    await tester.pumpAndSettle();

    expect(find.text('Tüm borçlar kapatılmış görünüyor.'), findsOneWidget);
  });

  testWidgets('masraf hata ekranındaki tekrar dene masrafları yeniden yükler', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: _RetryingExpenseRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    expect(
      find.byKey(const Key('retry_group_expenses_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('retry_group_expenses_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('retry_group_expenses_button')), findsNothing);
    expect(find.text('Henüz masraf yok'), findsOneWidget);
  });
}

Future<void> _pumpDetailPage(
  WidgetTester tester, {
  required FakeGroupRepository repository,
  String userId = currentUserId,
  String groupId = twoMemberGroupId,
  bool settle = true,
}) async {
  final controller = AuthSessionController(
    _DetailAuthRepository(userId: userId),
  );
  await controller.login('user@example.com', 'password');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => controller),
        groupRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(home: GroupDetailPage(groupId: groupId)),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  }
}

class _RetryingDetailRepository extends FakeGroupRepository {
  _RetryingDetailRepository({required super.groups});

  var _shouldFail = true;

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw groupsApiErrorException;
    }

    return super.getGroup(groupId);
  }
}

class _RetryingExpenseRepository extends FakeGroupRepository {
  _RetryingExpenseRepository({required super.groups});

  bool _shouldFail = true;

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) async {
    if (_shouldFail) {
      _shouldFail = false;
      throw groupsApiErrorException;
    }

    return super.listExpenses(groupId);
  }
}

class _DetailAuthRepository implements AuthRepositoryBase {
  const _DetailAuthRepository({required this.userId});

  final String userId;

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    return AuthUser(
      id: userId,
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
