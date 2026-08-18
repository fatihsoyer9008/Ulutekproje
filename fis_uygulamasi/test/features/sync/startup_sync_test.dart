import 'dart:async';

import 'package:app_main/core/database/database_providers.dart';
import 'package:app_main/core/network/network_connectivity_monitor.dart';
import 'package:app_main/features/auth/data/auth_repository.dart';
import 'package:app_main/features/auth/domain/auth_user.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/sync/application/automatic_sync_service.dart';
import 'package:app_main/features/sync/application/sync_coordinator.dart';
import 'package:app_main/features/sync/data/pending_task_sync_gateway.dart';
import 'package:app_main/src/app/finance_app.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
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
          networkConnectivityMonitorProvider.overrideWithValue(
            _OnlineConnectivityMonitor(),
          ),
          offlineQueueSummaryProvider.overrideWith(
            (ref) => Stream.value(const OfflineQueueSummary()),
          ),
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

  testWidgets(
    'offline durumdan online duruma geçince iki sync akışı tetiklenir',
    (tester) async {
      final authController = AuthSessionController(_SilentRefreshRepository());
      final connectivity = _ControlledConnectivityMonitor();
      var personalCalls = 0;
      var groupCalls = 0;
      final automaticSync = DefaultAutomaticSyncService(
        connectivity,
        () async {},
        () async {},
        () async => personalCalls += 1,
        () async => groupCalls += 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionControllerProvider.overrideWith((ref) => authController),
            networkConnectivityMonitorProvider.overrideWithValue(connectivity),
            automaticSyncServiceProvider.overrideWithValue(automaticSync),
            offlineQueueSummaryProvider.overrideWith(
              (ref) => Stream.value(const OfflineQueueSummary()),
            ),
          ],
          child: FinanceApp(
            enableAuth: true,
            enableStartupSync: true,
            transactionStream: Stream.value(const <TransactionEntity>[]),
            deepLinkStream: const Stream<Uri>.empty(),
            initialDeepLinkLoader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(personalCalls, 0);
      expect(groupCalls, 0);

      connectivity.setOnline(true);
      await tester.pumpAndSettle();

      expect(personalCalls, 1);
      expect(groupCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await connectivity.dispose();
    },
  );
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
  Future<Set<Id>> requeueFailedAndConflicted() async => const {};

  @override
  Future<Set<Id>> requeueRetryableFailures() async => const {};

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

class _OnlineConnectivityMonitor implements NetworkConnectivityMonitor {
  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> get onOnlineStatusChanged => const Stream<bool>.empty();
}

class _ControlledConnectivityMonitor implements NetworkConnectivityMonitor {
  final _controller = StreamController<bool>.broadcast();
  bool _online = false;

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> get onOnlineStatusChanged => _controller.stream;
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
