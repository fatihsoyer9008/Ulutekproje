import 'dart:async';

import 'package:app_main/core/network/network_connectivity_monitor.dart';
import 'package:app_main/features/sync/application/automatic_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline kayıttan sonra sync başlatmaz', () async {
    final monitor = _FakeConnectivityMonitor();
    var personalCalls = 0;
    var groupCalls = 0;
    final service = DefaultAutomaticSyncService(
      monitor,
      () async => personalCalls += 1,
      () async => groupCalls += 1,
      () async {},
      () async {},
    );

    await service.syncPersonalAfterSave();
    await service.syncGroupAfterSave();

    expect(personalCalls, 0);
    expect(groupCalls, 0);
  });

  test('online kayıttan sonra yalnız ilgili kuyruğu sync eder', () async {
    final monitor = _FakeConnectivityMonitor(online: true);
    var personalCalls = 0;
    var groupCalls = 0;
    final service = DefaultAutomaticSyncService(
      monitor,
      () async => personalCalls += 1,
      () async => groupCalls += 1,
      () async {},
      () async {},
    );

    await service.syncPersonalAfterSave();
    expect(personalCalls, 1);
    expect(groupCalls, 0);

    await service.syncGroupAfterSave();
    expect(personalCalls, 1);
    expect(groupCalls, 1);
  });

  test('bağlantı geri gelince kişisel ve grup sync birlikte çalışır', () async {
    final monitor = _FakeConnectivityMonitor(online: true);
    var personalCalls = 0;
    var groupCalls = 0;
    final service = DefaultAutomaticSyncService(
      monitor,
      () async {},
      () async {},
      () async => personalCalls += 1,
      () async => groupCalls += 1,
    );

    await service.syncAllAfterConnectivityRestored();

    expect(personalCalls, 1);
    expect(groupCalls, 1);
  });
}

class _FakeConnectivityMonitor implements NetworkConnectivityMonitor {
  _FakeConnectivityMonitor({this.online = false});

  bool online;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onOnlineStatusChanged => const Stream<bool>.empty();
}
