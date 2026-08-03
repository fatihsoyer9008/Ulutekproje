import 'dart:math';

import 'package:app_main/core/storage/installation_id_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('generates and persists a valid installation ID', () async {
    final firstProvider = PersistentInstallationIdProvider(random: Random(1));

    final firstId = await firstProvider.getInstallationId();
    final cachedId = await firstProvider.getInstallationId();

    final secondProvider = PersistentInstallationIdProvider(random: Random(2));
    final persistedId = await secondProvider.getInstallationId();

    expect(firstId, hasLength(32));
    expect(firstId, matches(RegExp(r'^[A-Za-z0-9._:-]{16,128}$')));
    expect(cachedId, firstId);
    expect(persistedId, firstId);
  });

  test('replaces an invalid persisted installation ID', () async {
    SharedPreferences.setMockInitialValues({
      'receipt_installation_id': 'invalid id',
    });
    final provider = PersistentInstallationIdProvider(random: Random(1));

    final installationId = await provider.getInstallationId();

    expect(installationId, hasLength(32));
    expect(installationId, isNot('invalid id'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('receipt_installation_id'), installationId);
  });

  test('shares one generated ID between concurrent first reads', () async {
    final provider = PersistentInstallationIdProvider(random: Random(1));

    final installationIds = await Future.wait([
      provider.getInstallationId(),
      provider.getInstallationId(),
      provider.getInstallationId(),
    ]);

    expect(installationIds.toSet(), hasLength(1));
  });
}
