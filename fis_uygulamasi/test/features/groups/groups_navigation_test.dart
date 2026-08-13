import 'package:app_main/features/ai_assistant/data/ai_assistant_client.dart';
import 'package:app_main/features/ai_assistant/presentation/assistant_consent_card.dart';
import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/presentation/groups_page.dart';
import 'package:app_main/features/groups/presentation/group_ocr_page.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(
      tester.widget<GroupOcrPage>(find.byType(GroupOcrPage)).groupId,
      '10000000-0000-4000-8000-000000000001',
    );
    expect(find.text('Ev Arkadaşları'), findsOneWidget);
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
  AuthSessionController controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => controller),
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

class _NavigationAuthRepository implements AuthRepositoryBase {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async => AuthUser(id: 'user-id', email: email, isEmailVerified: true);

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
