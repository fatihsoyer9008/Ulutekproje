import 'dart:async';

import 'package:app_main/features/ai_assistant/data/ai_assistant_client.dart';
import 'package:app_main/features/ai_assistant/presentation/assistant_consent_card.dart';
import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/data/fake_group_repository.dart'
    show FakeGroupRepository;
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/data/group_repository.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/presentation/group_ocr_page.dart';
import 'package:app_main/features/groups/presentation/groups_page.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  testWidgets('authenticated user opens groups from the drawer', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);

    expect(find.byType(GroupsPage), findsOneWidget);
  });

  testWidgets('grup detayındaki Fiş Tara ayrı grup OCR routeunu açar', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);
    await tester.tap(find.text('Ev Arkadaşları'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_group_expense_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('select_scan_receipt_button')));
    await tester.pumpAndSettle();

    expect(find.byType(GroupOcrPage), findsOneWidget);
    final groupOcrPage = tester.widget<GroupOcrPage>(find.byType(GroupOcrPage));
    expect(groupOcrPage.group.id, '10000000-0000-4000-8000-000000000001');
    expect(groupOcrPage.group.name, 'Ev Arkadaşları');
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
  });
  testWidgets('OCR route state.extra olmadan grup bilgisini yükler', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);

    final routerContext = tester.element(
      find.byKey(const Key('app_menu_button')),
    );

    GoRouter.of(
      routerContext,
    ).go('/groups/10000000-0000-4000-8000-000000000001/ocr');

    await tester.pumpAndSettle();

    expect(find.byType(GroupOcrPage), findsOneWidget);

    final groupOcrPage = tester.widget<GroupOcrPage>(find.byType(GroupOcrPage));

    expect(groupOcrPage.group.id, '10000000-0000-4000-8000-000000000001');
    expect(groupOcrPage.group.name, 'Ev Arkadaşları');
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
  });

  testWidgets('OCR route grup yükleme hatasında retry ile açılır', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    final repository = _RetryingOcrRouteRepository();

    await _pumpApp(tester, controller, groupRepository: repository);

    final routerContext = tester.element(
      find.byKey(const Key('app_menu_button')),
    );

    GoRouter.of(routerContext).go('/groups/$twoMemberGroupId/ocr');

    await tester.pumpAndSettle();

    expect(repository.getGroupCalls, 1);
    expect(find.byType(GroupOcrPage), findsNothing);
    expect(
      find.text(
        'Grup bilgisi yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tekrar Dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(repository.getGroupCalls, 2);
    expect(find.byType(GroupOcrPage), findsOneWidget);

    final groupOcrPage = tester.widget<GroupOcrPage>(find.byType(GroupOcrPage));

    expect(groupOcrPage.group.id, twoMemberGroupId);
    expect(groupOcrPage.group.name, 'Ev Arkadaşları');
  });

  testWidgets('guest returns to groups after email login', (tester) async {
    final controller = AuthSessionController(_NavigationAuthRepository())
      ..continueAsGuest();

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);

    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(GroupsPage), findsOneWidget);
  });

  testWidgets('guest returns to groups after Google login', (tester) async {
    final controller = AuthSessionController(_NavigationAuthRepository())
      ..continueAsGuest();

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);
    final googleLoginButton = find.byKey(const Key('google_login_button'));
    await tester.ensureVisible(googleLoginButton);
    await tester.pumpAndSettle();
    await tester.tap(googleLoginButton);
    await tester.pumpAndSettle();

    expect(find.byType(GroupsPage), findsOneWidget);
  });

  testWidgets('expired API session redirects protected group route to login', (
    tester,
  ) async {
    final unauthorizedEvents = StreamController<void>();
    addTearDown(unauthorizedEvents.close);
    final controller = AuthSessionController(
      _NavigationAuthRepository(),
      unauthorizedEvents: unauthorizedEvents.stream,
    );
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await _openGroupsFromDrawer(tester);
    expect(find.byType(GroupsPage), findsOneWidget);

    unauthorizedEvents.add(null);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
    expect(find.textContaining('Oturum süreniz doldu'), findsOneWidget);
  });

  testWidgets('profile route keeps the AI assistant consent card', (
    tester,
  ) async {
    final controller = AuthSessionController(_NavigationAuthRepository());
    await controller.login('user@example.com', 'password');

    await _pumpApp(tester, controller);
    await tester.tap(find.byKey(const Key('app_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_profile_tile')));
    await tester.pumpAndSettle();

    expect(find.byType(AssistantConsentCard), findsOneWidget);
    expect(find.byKey(const Key('assistant_consent_card')), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  AuthSessionController controller, {
  GroupRepository? groupRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => controller),
        groupRepositoryProvider.overrideWithValue(
          groupRepository ??
              FakeGroupRepository(
                currentUserId: currentUserId,
                groups: const [twoMemberGroup],
                debtSummariesByGroup: const {
                  twoMemberGroupId: currentUserDebtorDebtSummary,
                },
              ),
        ),
      ],
      child: FinanceApp(
        enableAuth: true,
        transactionStream: Stream.value(const <TransactionEntity>[]),
        profileAiAssistantClient: _FakeAssistantClient(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openGroupsFromDrawer(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('app_menu_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('drawer_groups_tile')));
  await tester.pumpAndSettle();
}

class _RetryingOcrRouteRepository extends FakeGroupRepository {
  _RetryingOcrRouteRepository()
    : super(currentUserId: currentUserId, groups: const [twoMemberGroup]);

  var getGroupCalls = 0;
  var _shouldFail = true;

  @override
  Future<GroupDetail> getGroup(String groupId) async {
    getGroupCalls += 1;

    if (_shouldFail) {
      _shouldFail = false;
      throw groupsApiErrorException;
    }

    return super.getGroup(groupId);
  }
}

class _NavigationAuthRepository implements AuthRepositoryBase {
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
  Future<String> verifyEmail(String token) async => 'Verified';
}

class _FakeAssistantClient implements AiAssistantAccessClient {
  @override
  Future<AiAssistantStatus> fetchStatus() async => const AiAssistantStatus(
    enabled: true,
    requiredConsentVersion: 'v1',
    consentGranted: false,
  );

  @override
  Future<AiAssistantStatus> updateConsent({
    required bool accepted,
    required String consentVersion,
  }) async => AiAssistantStatus(
    enabled: true,
    requiredConsentVersion: consentVersion,
    consentGranted: accepted,
  );
}
