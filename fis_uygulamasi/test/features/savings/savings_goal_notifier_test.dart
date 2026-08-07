import 'package:app_main/core/database/database_providers.dart';
import 'package:app_main/core/storage/installation_id_provider.dart';
import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/savings/application/savings_goal_notifier.dart';
import 'package:app_main/features/sync/application/sync_coordinator.dart';
import 'package:app_main/src/screens/savings_screen.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  test('repository yükleme hatasını AsyncError olarak yansıtır', () async {
    final notifier = SavingsGoalNotifier(
      _FakeSavingsGoalStore(loadError: StateError('boom')),
      ownerKey: 'user:a',
    );
    addTearDown(notifier.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.hasError, isTrue);
  });

  test('auth değiştiğinde aktif sahip anahtarı değişir', () async {
    final auth = AuthSessionController(_FakeAuthRepository());
    final container = ProviderContainer(
      overrides: [
        authSessionControllerProvider.overrideWith((ref) => auth),
        installationIdProvider.overrideWithValue(_FakeInstallationIdProvider()),
      ],
    );
    addTearDown(container.dispose);

    auth.continueAsGuest();
    expect(
      await container.read(activeSavingsOwnerKeyProvider.future),
      'guest:installation-123456',
    );

    await auth.login('a@example.com', 'password');
    expect(
      await container.read(activeSavingsOwnerKeyProvider.future),
      'user:user-a',
    );
  });

  testWidgets('A hesabından B hesabına geçince ekrandaki hedefler taşınmaz', (
    tester,
  ) async {
    final auth = AuthSessionController(_FakeAuthRepository());
    final store = _FakeSavingsGoalStore(
      goals: [
        _goal('A kullanıcısının hedefi', 'user:user-a'),
        _goal('B kullanıcısının hedefi', 'user:user-b'),
      ],
    );
    await auth.login('a@example.com', 'password');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith((ref) => auth),
          installationIdProvider.overrideWithValue(
            _FakeInstallationIdProvider(),
          ),
          savingsGoalRepositoryProvider.overrideWithValue(store),
        ],
        child: const MaterialApp(home: Scaffold(body: SavingsScreen.live())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A kullanıcısının hedefi'), findsOneWidget);
    expect(find.text('B kullanıcısının hedefi'), findsNothing);

    await auth.login('b@example.com', 'password');
    await tester.pumpAndSettle();

    expect(find.text('A kullanıcısının hedefi'), findsNothing);
    expect(find.text('B kullanıcısının hedefi'), findsOneWidget);
  });
}

SavingsGoalEntity _goal(String title, String ownerKey) => SavingsGoalEntity()
  ..title = title
  ..targetAmountInMinor = 100000
  ..createdAt = DateTime(2026, 8, 7)
  ..ownerKey = ownerKey;

class _FakeSavingsGoalStore implements SavingsGoalStore {
  _FakeSavingsGoalStore({this.loadError, this.goals = const []});
  final Object? loadError;
  final List<SavingsGoalEntity> goals;

  @override
  Future<List<SavingsGoalEntity>> getGoals({required String ownerKey}) async {
    if (loadError != null) throw loadError!;
    return goals.where((goal) => goal.ownerKey == ownerKey).toList();
  }

  @override
  Future<Id> addGoal(
    SavingsGoalEntity goal, {
    required String ownerKey,
  }) async => 1;

  @override
  Future<void> deleteGoal(Id id, {required String ownerKey}) async {}

  @override
  Future<void> updateGoalAmount(
    Id id,
    int amountInMinor, {
    required String ownerKey,
  }) async {}
}

class _FakeInstallationIdProvider implements InstallationIdProvider {
  @override
  Future<String> getInstallationId() async => 'installation-123456';
}

class _FakeAuthRepository implements AuthRepositoryBase {
  @override
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final suffix = email.startsWith('b@') ? 'b' : 'a';
    return AuthUser(id: 'user-$suffix', email: email, isEmailVerified: true);
  }

  @override
  Future<void> deleteAccount({String? currentPassword}) async {}
  @override
  Future<String> forgotPassword(String email) async => '';
  @override
  Future<void> logout() async {}
  @override
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) async => '';
  @override
  Future<String> resendVerification(String email) async => '';
  @override
  Future<AuthUser?> silentRefresh() async => null;
  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<String> verifyEmail(String token) async => '';
}
