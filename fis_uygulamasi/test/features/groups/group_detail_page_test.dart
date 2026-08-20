import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/group_detail_page.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

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
    expect(
      tester.getSize(find.byKey(const Key('group_detail_scroll_view'))).height,
      greaterThan(0),
    );
    final groupNameRect = tester.getRect(
      find.byKey(const Key('group_detail_name')),
    );
    expect(groupNameRect.bottom, greaterThan(0));
    expect(groupNameRect.top, lessThan(tester.view.physicalSize.height));
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
    expect(find.byKey(const Key('group_detail_avatar')), findsOneWidget);
    expect(find.text('2 kişi'), findsOneWidget);
    expect(find.text('Ödeme tarihi ekle'), findsOneWidget);
    expect(find.text('Ödeme yap'), findsOneWidget);
    expect(find.text('Grafikler'), findsOneWidget);
    expect(find.text('Bakiyeler'), findsOneWidget);
    expect(find.text('Harcama ekle'), findsOneWidget);
    expect(find.text('Borç Özetini Görüntüle'), findsNothing);
    final contentPadding = tester.widget<SliverPadding>(
      find.byKey(const Key('group_detail_content_padding')),
    );
    expect(
      (contentPadding.padding as EdgeInsets).bottom,
      greaterThanOrEqualTo(96),
    );

    expect(find.text('Aylık market alışverişi'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('add_group_member_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Üyeler'), findsOneWidget);
    expect(find.text('Zafer Tuna', skipOffstage: false), findsOneWidget);
    expect(find.text('Abdullah Seydi', skipOffstage: false), findsOneWidget);
    expect(
      find.byKey(const Key('group_role_owner'), skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.byKey(const Key('group_role_member'), skipOffstage: false),
      findsWidgets,
    );
  });

  testWidgets('iki kişilik grupta bakiye karşı üyenin adıyla gösterilir', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        debtSummariesByGroup: const <String, DebtSummary>{
          twoMemberGroupId: currentUserDebtorDebtSummary,
        },
      ),
    );

    expect(find.textContaining("Abdullah Seydi'ye borcunuz:"), findsOneWidget);
    expect(find.textContaining('₺ 62.50'), findsOneWidget);
  });

  testWidgets('çok üyeli grupta kişi adı yerine grup net bakiyesi gösterilir', (
    tester,
  ) async {
    const summary = DebtSummary(
      groupId: fourMemberGroupId,
      currency: 'TRY',
      balances: <DebtBalance>[
        DebtBalance(
          userId: currentUserId,
          displayName: 'Zafer Tuna',
          netAmountInMinor: 18750,
        ),
      ],
      suggestedTransfers: <DebtTransfer>[],
      generatedAt: '2026-08-20T12:00:00Z',
    );
    await _pumpDetailPage(
      tester,
      groupId: fourMemberGroupId,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[fourMemberGroup],
        debtSummariesByGroup: const <String, DebtSummary>{
          fourMemberGroupId: summary,
        },
      ),
    );

    expect(find.textContaining('Gruptan alacağınız:'), findsOneWidget);
    expect(find.textContaining('Feyza'), findsNothing);
  });

  testWidgets('ödeme tarihi seçilince tarih çip üzerinde gösterilir', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    await tester.tap(find.byKey(const Key('settle_up_date_chip')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    calendar.onDateChanged(DateTime(2027, 3, 14));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();

    expect(find.text('Ödeme: 14.03.2027'), findsOneWidget);
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
      tester
          .widget<IconButton>(find.byKey(const Key('add_group_member_button')))
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const Key('group_invitation_unavailable_message')),
      findsNothing,
    );
    expect(
      find.byKey(Key('remove_group_member_$secondUserId')),
      findsOneWidget,
    );
    expect(find.byKey(Key('remove_group_member_$currentUserId')), findsNothing);
  });

  testWidgets('ayarlar kapsamlı grup ayarları menüsünü açar', (tester) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Grup Ayarları'), findsOneWidget);
    expect(find.byKey(const Key('edit_group_settings')), findsOneWidget);
    expect(find.byKey(const Key('group_photo_settings')), findsOneWidget);
    expect(find.byKey(const Key('manage_group_members')), findsOneWidget);
    expect(find.byKey(const Key('group_notifications_switch')), findsOneWidget);
    expect(find.text('TRY (₺)'), findsOneWidget);
    expect(find.byKey(const Key('leave_group_settings')), findsOneWidget);
    expect(
      find.byKey(const Key('delete_group_settings'), skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('group_photo_settings')));
    await tester.pumpAndSettle();

    expect(find.text('Grup fotoğrafı'), findsOneWidget);
    expect(find.byKey(const Key('pick_group_cover_gallery')), findsOneWidget);
    expect(find.byKey(const Key('pick_group_cover_camera')), findsOneWidget);
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

  testWidgets('gerçek API modunda davet aksiyonu capability ile kapatılır', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: _InvitationUnavailableRepository(
        groups: const <GroupDetail>[twoMemberGroup],
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('add_group_member_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    final button = tester.widget<IconButton>(
      find.byKey(const Key('add_group_member_button')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Davet sistemi hazırlanıyor'), findsOneWidget);
    expect(
      find.byKey(const Key('group_invitation_unavailable_message')),
      findsOneWidget,
    );
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
    expect(find.byKey(const Key('select_scan_receipt_button')), findsOneWidget);
    expect(
      find.byKey(const Key('select_gallery_receipt_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('select_fast_split_button')), findsOneWidget);
    expect(find.text('Fiş Tara'), findsOneWidget);
    expect(find.text('Galeriden Seç'), findsOneWidget);
    expect(find.text('Manuel Ekle'), findsOneWidget);
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

    expect(find.byKey(const Key('group_detail_loading')), findsOneWidget);

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
    expect(find.text('Grup bilgileri şu anda alınamıyor.'), findsOneWidget);
    expect(find.byKey(const Key('group_detail_error_message')), findsOneWidget);
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

    expect(
      find.byKey(const Key('group_detail_name'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Ev Arkadaşları', skipOffstage: false), findsOneWidget);

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

  testWidgets('masraf sahibi başlık ve notu düzenleyebilir', (tester) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        expensesByGroup: const <String, List<GroupExpense>>{
          twoMemberGroupId: <GroupExpense>[fastSplitTransferExpense],
        },
      ),
    );

    await tester.tap(
      find.byKey(Key('group_expense_actions_${fastSplitTransferExpense.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('edit_group_expense_${fastSplitTransferExpense.id}')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('edit_group_expense_title_field')),
      'Güncellenen market',
    );
    await tester.enterText(
      find.byKey(const Key('edit_group_expense_note_field')),
      'Yeni not',
    );
    await tester.tap(find.byKey(const Key('save_group_expense_update_button')));
    await tester.pumpAndSettle();

    expect(find.text('Güncellenen market'), findsOneWidget);
    expect(find.text('Masraf güncellemesi kaydedildi.'), findsOneWidget);
  });

  testWidgets('masraf sahibi onay sonrasında masrafı silebilir', (
    tester,
  ) async {
    await _pumpDetailPage(
      tester,
      repository: FakeGroupRepository(
        groups: const <GroupDetail>[twoMemberGroup],
        expensesByGroup: const <String, List<GroupExpense>>{
          twoMemberGroupId: <GroupExpense>[fastSplitTransferExpense],
        },
      ),
    );

    await tester.tap(
      find.byKey(Key('group_expense_actions_${fastSplitTransferExpense.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('delete_group_expense_${fastSplitTransferExpense.id}')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('delete_group_expense_confirmation_dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('confirm_delete_group_expense_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text(fastSplitTransferExpense.title), findsNothing);
    expect(find.text('Henüz masraf yok'), findsOneWidget);
    expect(find.text('Masraf silme kuyruğuna eklendi.'), findsOneWidget);
  });

  testWidgets(
    'masraf sahibi olmayan member update delete aksiyonlarını görmez',
    (tester) async {
      await _pumpDetailPage(
        tester,
        repository: FakeGroupRepository(
          currentUserId: secondUserId,
          groups: const <GroupDetail>[twoMemberGroup],
          expensesByGroup: const <String, List<GroupExpense>>{
            twoMemberGroupId: <GroupExpense>[fastSplitTransferExpense],
          },
        ),
        userId: secondUserId,
      );

      expect(
        find.byKey(Key('group_expense_actions_${fastSplitTransferExpense.id}')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'finansal olarak kilitli masrafın delete aksiyonu devre dışıdır',
    (tester) async {
      final locked = GroupExpense.fromJson(<String, Object?>{
        ...fastSplitTransferExpense.toJson(),
        'is_financially_locked': true,
      });
      await _pumpDetailPage(
        tester,
        repository: FakeGroupRepository(
          groups: const <GroupDetail>[twoMemberGroup],
          expensesByGroup: <String, List<GroupExpense>>{
            twoMemberGroupId: <GroupExpense>[locked],
          },
        ),
      );

      await tester.tap(
        find.byKey(Key('group_expense_actions_${fastSplitTransferExpense.id}')),
      );
      await tester.pumpAndSettle();
      final deleteItem = tester.widget<PopupMenuItem>(
        find.byKey(Key('delete_group_expense_${fastSplitTransferExpense.id}')),
      );
      expect(deleteItem.enabled, isFalse);
      expect(find.text('Sil (finansal olarak kilitli)'), findsOneWidget);
    },
  );
}

Future<void> _pumpDetailPage(
  WidgetTester tester, {
  required GroupRepository repository,
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
      child: MaterialApp(
        theme: AppTheme.light,
        home: GroupDetailPage(groupId: groupId),
      ),
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

class _InvitationUnavailableRepository extends FakeGroupRepository {
  _InvitationUnavailableRepository({required super.groups});

  @override
  GroupRepositoryCapabilities get capabilities =>
      const GroupRepositoryCapabilities(supportsInvitations: false);
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
  Future<AuthUser> updateAvatar(String avatarId) async =>
      throw UnimplementedError();

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
