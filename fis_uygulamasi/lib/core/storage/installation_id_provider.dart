import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

abstract interface class InstallationIdProvider {
  Future<String> getInstallationId();
}

class PersistentInstallationIdProvider implements InstallationIdProvider {
  PersistentInstallationIdProvider({Random? random})
    : _random = random ?? Random.secure();

  static const _storageKey = 'receipt_installation_id';
  static final _validInstallationId = RegExp(r'^[A-Za-z0-9._:-]{16,128}$');

  final Random _random;

  String? _cachedId;
  Future<String>? _pendingOperation;

  @override
  Future<String> getInstallationId() async {
    final cachedId = _cachedId;
    if (cachedId != null) return cachedId;

    final pendingOperation = _pendingOperation;
    if (pendingOperation != null) return pendingOperation;

    final operation = _loadOrCreateInstallationId();
    _pendingOperation = operation;

    try {
      final installationId = await operation;
      _cachedId = installationId;
      return installationId;
    } finally {
      if (identical(_pendingOperation, operation)) {
        _pendingOperation = null;
      }
    }
  }

  Future<String> _loadOrCreateInstallationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existingId = preferences.getString(_storageKey);

    if (existingId != null && _validInstallationId.hasMatch(existingId)) {
      return existingId;
    }

    final installationId = _generateInstallationId();
    final saved = await preferences.setString(_storageKey, installationId);

    if (!saved) {
      throw StateError('Kurulum kimliği kalıcı olarak kaydedilemedi.');
    }

    return installationId;
  }

  String _generateInstallationId() {
    final bytes = Uint8List.fromList(
      List<int>.generate(24, (_) => _random.nextInt(256)),
    );

    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
