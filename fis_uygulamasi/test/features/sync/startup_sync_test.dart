import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/sync/application/sync_coordinator.dart';
import 'package:app_main/features/sync/data/pending_task_sync_gateway.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  testWidgets('uygulama açılışı ve silent refresh pending görevleri gönderir', (
    tester,
  ) async {
    final authController = AuthSessionController(_SilentRefreshRepository());
    final task = OfflineTask()
      ..id = 1
      ..clientTaskId = 'operation-1'
      ..payloadJson = '{}'
      ..createdAt = DateTime(2026)
      ..updatedAt = DateTime(2026);
    final repository = _StartupRepository(task);
    final gateway = _CountingGateway();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith((ref) => authController),
          syncTaskRepositoryProvider.overrideWithValue(repository),
          pendingTaskSyncGatewayProvider.overrideWithValue(gateway),
        ],
        child: FinanceApp(
          enableAuth: true,
          enableStartupSync: true,
          transactionStream: Stream.value(const <TransactionEntity>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.calls, 1);
    expect(repository.syncedIds, [1]);
    expect(authController.state.status, AuthStatus.authenticated);
    expect(tester.takeException(), isNull);
  });
}

class _CountingGateway implements PendingTaskSyncGateway {
  int calls = 0;

  @override
  Future<void> send(OfflineTask task) async => calls += 1;
}

class _StartupRepository implements SyncTaskRepository {
  _StartupRepository(this.task);

  OfflineTask? task;
  final syncedIds = <Id>[];

  @override
  Future<List<OfflineTask>> getPendingTasks({int limit = 50}) async =>
      task == null ? const [] : [task!];

  @override
  Future<void> markAsSynced(Id id) async {
    syncedIds.add(id);
    task = null;
  }

  @override
  Future<int> deleteSyncedBefore(DateTime cutoff, {int limit = 100}) async => 0;

  @override
  Future<void> markConflict(Id id, String error) async => task = null;

  @override
  Future<void> markPermanentlyFailed(Id id, String error) async => task = null;

  @override
  Future<void> updateTaskError(Id id, String error) async {}
}

class _SilentRefreshRepository implements AuthRepositoryBase {
  @override
  Future<AuthUser?> silentRefresh() async => const AuthUser(
    id: 'user-id',
    email: 'user@example.com',
    isEmailVerified: true,
  );

  @override
  Future<void> deleteAccount({String? currentPassword}) async {}

  @override
  Future<String> forgotPassword(String email) async => 'Sent';

  @override
  Future<AuthUser> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<String> register({
    required String email,
    required String password,
    String? displayName,
  }) => throw UnimplementedError();

  @override
  Future<String> resendVerification(String email) => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<String> verifyEmail(String token) => throw UnimplementedError();
}
