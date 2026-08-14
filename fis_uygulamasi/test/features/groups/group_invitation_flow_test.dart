import 'dart:async';

import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/group_detail_page.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets(
    'davet deep-linki accept çağırır ve ilgili grup detayına yönlendirir',
    (tester) async {
      final auth = AuthSessionController(_InvitationAuthRepository());
      await auth.login('user@example.com', 'password');
      final repository = _InvitationRepository();

      await _pumpInvitationApp(
        tester,
        auth: auth,
        repository: repository,
        deepLinks: Stream.value(_invitationUri('accepted-token')),
      );

      expect(repository.acceptedTokens, ['accepted-token']);
      expect(find.byType(GroupDetailPage), findsOneWidget);
      expect(
        tester.widget<GroupDetailPage>(find.byType(GroupDetailPage)).groupId,
        twoMemberGroupId,
      );
      expect(find.text('Grup daveti kabul edildi.'), findsOneWidget);
    },
  );

  testWidgets('kapalı uygulama initial link ile daveti kabul eder', (
    tester,
  ) async {
    final auth = AuthSessionController(_InvitationAuthRepository());
    await auth.login('user@example.com', 'password');
    final repository = _InvitationRepository();

    await _pumpInvitationApp(
      tester,
      auth: auth,
      repository: repository,
      initialDeepLink: _invitationUri('cold-start-token'),
    );

    expect(repository.acceptedTokens, ['cold-start-token']);
    expect(find.byType(GroupDetailPage), findsOneWidget);
  });

  testWidgets(
    'kapalı uygulamada giriş yapmamış kullanıcı login sonrası daveti kabul eder',
    (tester) async {
      final auth = AuthSessionController(_InvitationAuthRepository());
      final repository = _InvitationRepository();

      await _pumpInvitationApp(
        tester,
        auth: auth,
        repository: repository,
        initialDeepLink: _invitationUri('pending-login-token'),
      );

      expect(repository.acceptedTokens, isEmpty);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(
        find.text('Grup davetini kabul etmek için giriş yapın.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(repository.acceptedTokens, ['pending-login-token']);
      expect(find.byType(GroupDetailPage), findsOneWidget);
    },
  );

  testWidgets('initial ve stream aynı daveti yalnızca bir kez işler', (
    tester,
  ) async {
    final auth = AuthSessionController(_InvitationAuthRepository());
    await auth.login('user@example.com', 'password');
    final repository = _InvitationRepository();
    final uri = _invitationUri('duplicate-token');

    await _pumpInvitationApp(
      tester,
      auth: auth,
      repository: repository,
      initialDeepLink: uri,
      deepLinks: Stream.value(uri),
    );

    expect(repository.acceptedTokens, ['duplicate-token']);
  });

  testWidgets('ortak deep-link dinleyicisi e-posta doğrulamayı korur', (
    tester,
  ) async {
    final authRepository = _InvitationAuthRepository();
    final auth = AuthSessionController(authRepository);

    await _pumpInvitationApp(
      tester,
      auth: auth,
      repository: _InvitationRepository(),
      deepLinks: Stream.value(
        Uri.parse('fiskon://auth/verify-email?token=verify-token'),
      ),
    );

    expect(authRepository.verifiedTokens, ['verify-token']);
    expect(find.text('E-postanı doğrula'), findsOneWidget);
  });

  for (final testCase in <({int status, String code, String message})>[
    (
      status: 410,
      code: 'invitation_expired_or_used',
      message: 'Bu davetin süresi dolmuş veya davet daha önce kullanılmış.',
    ),
    (
      status: 403,
      code: 'invitation_email_mismatch',
      message: 'Bu davet farklı bir e-posta hesabına ait.',
    ),
  ]) {
    testWidgets('${testCase.status} davet hatası kullanıcı dostu gösterilir', (
      tester,
    ) async {
      final auth = AuthSessionController(_InvitationAuthRepository());
      await auth.login('user@example.com', 'password');
      final repository = _InvitationRepository(
        acceptError: GroupApiException(
          statusCode: testCase.status,
          error: GroupApiError(
            detail: GroupApiErrorDetail(
              code: testCase.code,
              message: 'Backend error',
            ),
          ),
        ),
      );

      await _pumpInvitationApp(
        tester,
        auth: auth,
        repository: repository,
        initialDeepLink: testCase.status == 410
            ? _invitationUri('invalid-token')
            : null,
        deepLinks: testCase.status == 410
            ? const Stream<Uri>.empty()
            : Stream.value(_invitationUri('invalid-token')),
      );

      expect(repository.acceptedTokens, ['invalid-token']);
      expect(find.text(testCase.message), findsOneWidget);
      expect(find.byType(GroupDetailPage), findsNothing);
    });
  }
}

Future<void> _pumpInvitationApp(
  WidgetTester tester, {
  required AuthSessionController auth,
  required _InvitationRepository repository,
  Stream<Uri> deepLinks = const Stream<Uri>.empty(),
  Uri? initialDeepLink,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => auth),
        groupRepositoryProvider.overrideWithValue(repository),
      ],
      child: FinanceApp(
        enableAuth: true,
        transactionStream: Stream.value(const <TransactionEntity>[]),
        deepLinkStream: deepLinks,
        initialDeepLinkLoader: () async => initialDeepLink,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Uri _invitationUri(String token) =>
    Uri.parse('fiskon://auth/group-invitation?token=$token');

class _InvitationRepository extends FakeGroupRepository {
  _InvitationRepository({this.acceptError})
    : super(
        currentUserId: currentUserId,
        groups: const [twoMemberGroup],
        debtSummariesByGroup: const {
          twoMemberGroupId: currentUserDebtorDebtSummary,
        },
      );

  final GroupApiException? acceptError;
  final List<String> acceptedTokens = [];

  @override
  Future<GroupMember> acceptInvitation(String token) async {
    acceptedTokens.add(token);
    final error = acceptError;
    if (error != null) throw error;
    return twoMemberGroup.members.first;
  }
}

class _InvitationAuthRepository implements AuthRepositoryBase {
  final List<String> verifiedTokens = [];

  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => AuthUser(id: currentUserId, email: email, isEmailVerified: true);

  @override
  Future<AuthUser> signInWithGoogle() =>
      login(email: 'google@example.com', password: 'unused');

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
  Future<String> verifyEmail(String token) async {
    verifiedTokens.add(token);
    return 'Verified';
  }
}
