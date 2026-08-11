import 'dart:convert';
import 'dart:io';

import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixtureDirectory = Directory.current.parent
      .uri
      .resolve('docs/fixtures/group_debts/');

  for (final fixtureName in <String>[
    'debt_summary_2_members.json',
    'debt_summary_2_members_current_user_creditor.json',
    'debt_summary_3_members.json',
    'debt_summary_5_members.json',
  ]) {
    test('$fixtureName matches the Flutter DebtSummary contract', () async {
      final fixture = File.fromUri(fixtureDirectory.resolve(fixtureName));
      final json = (jsonDecode(await fixture.readAsString()) as Map)
          .cast<String, Object?>();

      final summary = DebtSummary.fromJson(json);

      expect(summary.toJson(), json);
      expect(DateTime.parse(summary.generatedAt).isUtc, isTrue);
      expect(
        summary.balances.fold<int>(
          0,
          (total, balance) => total + balance.netAmountInMinor,
        ),
        0,
      );
      expect(
        summary.suggestedTransfers.every(
          (transfer) => transfer.amountInMinor > 0,
        ),
        isTrue,
      );
    });
  }
}
