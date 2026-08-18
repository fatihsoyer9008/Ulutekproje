import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_connectivity_monitor.dart';
import '../../groups/application/group_sync_coordinator.dart';
import 'sync_coordinator.dart';

abstract interface class AutomaticSyncService {
  Future<bool> isOnline();

  Future<void> syncPersonalAfterSave();

  Future<void> syncGroupAfterSave();

  Future<void> syncAllAfterConnectivityRestored();
}

class DefaultAutomaticSyncService implements AutomaticSyncService {
  const DefaultAutomaticSyncService(
    this._connectivity,
    this._syncPersonalAfterSave,
    this._syncGroupAfterSave,
    this._syncPersonalAfterConnectivityRestored,
    this._syncGroupAfterConnectivityRestored,
  );

  final NetworkConnectivityMonitor _connectivity;
  final Future<void> Function() _syncPersonalAfterSave;
  final Future<void> Function() _syncGroupAfterSave;
  final Future<void> Function() _syncPersonalAfterConnectivityRestored;
  final Future<void> Function() _syncGroupAfterConnectivityRestored;

  @override
  Future<bool> isOnline() async {
    try {
      return await _connectivity.isOnline();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> syncPersonalAfterSave() => _syncIfOnline(_syncPersonalAfterSave);

  @override
  Future<void> syncGroupAfterSave() => _syncIfOnline(_syncGroupAfterSave);

  @override
  Future<void> syncAllAfterConnectivityRestored() async {
    if (!await isOnline()) return;
    await Future.wait<void>([
      _syncPersonalAfterConnectivityRestored(),
      _syncGroupAfterConnectivityRestored(),
    ]);
  }

  Future<void> _syncIfOnline(Future<void> Function() synchronize) async {
    if (await isOnline()) await synchronize();
  }
}

final automaticSyncServiceProvider = Provider<AutomaticSyncService>(
  (ref) => DefaultAutomaticSyncService(
    ref.watch(networkConnectivityMonitorProvider),
    () => ref.read(syncCoordinatorProvider.notifier).syncAfterSave(),
    () => ref.read(groupSyncCoordinatorProvider.notifier).syncAfterSave(),
    () => ref
        .read(syncCoordinatorProvider.notifier)
        .syncAfterConnectivityRestored(),
    () => ref
        .read(groupSyncCoordinatorProvider.notifier)
        .syncAfterConnectivityRestored(),
  ),
);
