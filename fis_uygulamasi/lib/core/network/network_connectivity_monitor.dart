import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class NetworkConnectivityMonitor {
  Future<bool> isOnline();

  Stream<bool> get onOnlineStatusChanged;
}

class ConnectivityPlusNetworkMonitor implements NetworkConnectivityMonitor {
  ConnectivityPlusNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onOnlineStatusChanged =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

final networkConnectivityMonitorProvider = Provider<NetworkConnectivityMonitor>(
  (ref) => ConnectivityPlusNetworkMonitor(),
);
