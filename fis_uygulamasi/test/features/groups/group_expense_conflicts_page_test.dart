import 'package:app_main/features/groups/application/group_expense_conflict_service.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:app_main/features/groups/domain/group_offline_operation.dart';
import 'package:app_main/features/groups/presentation/group_expense_conflicts_page.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';
import '../../fixtures/group_offline_operation_fixtures.dart';

void main() {
  testWidgets('yerel sürüm onay sonrasında resolvera gönderilir', (
    tester,
  ) async {
    final conflict = _conflict();
    final resolver = _FakeConflictResolver([conflict]);
    await _pumpPage(tester, resolver);

    expect(find.text('Yerel değişiklik'), findsOneWidget);
    expect(find.text('Başka cihazda güncellendi.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('keep_local_conflict_7')));
    await tester.pumpAndSettle();
    expect(find.text('Yerel değişiklik korunsun mu?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_conflict_resolution_7')));
    await tester.pumpAndSettle();

    expect(resolver.keepLocalCalls, 1);
    expect(resolver.useServerCalls, 0);
    expect(find.text('Masraf çakışması çözüldü.'), findsOneWidget);
  });

  testWidgets('sunucu sürümü onay sonrasında resolvera gönderilir', (
    tester,
  ) async {
    final conflict = _conflict();
    final resolver = _FakeConflictResolver([conflict]);
    await _pumpPage(tester, resolver);

    await tester.tap(find.byKey(const Key('use_server_conflict_7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_conflict_resolution_7')));
    await tester.pumpAndSettle();

    expect(resolver.useServerCalls, 1);
    expect(resolver.keepLocalCalls, 0);
  });

  testWidgets('finansal kilit conflictında yerel sürüm butonu pasiftir', (
    tester,
  ) async {
    final resolver = _FakeConflictResolver([
      _conflict(code: 'expense_financially_locked'),
    ]);
    await _pumpPage(tester, resolver);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('keep_local_conflict_7')),
    );
    expect(button.onPressed, isNull);
    expect(
      find.textContaining('yerel sürüm tekrar gönderilemez'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeConflictResolver resolver,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentGroupUserIdProvider.overrideWithValue(currentUserId),
        groupExpenseConflictServiceProvider.overrideWithValue(resolver),
        groupExpenseConflictsProvider.overrideWith(
          (ref) => Stream.value(resolver.conflicts),
        ),
      ],
      child: const MaterialApp(home: GroupExpenseConflictsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

GroupExpenseConflict _conflict({String? code = 'version_mismatch'}) {
  final local = GroupExpense.fromJson(<String, Object?>{
    ...fastSplitTransferExpense.toJson(),
    'title': 'Yerel değişiklik',
  });
  return GroupExpenseConflict(
    taskId: 7,
    operation: GroupExpenseOfflineOperation.update(
      expense: local,
      clientRecordId: '67000000-0000-4000-8000-000000000001',
      ownerKey: groupOperationOwnerKey,
      syncState: SyncState.failed,
    ),
    localExpense: local,
    code: code,
    message: 'Başka cihazda güncellendi.',
  );
}

class _FakeConflictResolver implements GroupExpenseConflictResolver {
  _FakeConflictResolver(this.conflicts);

  final List<GroupExpenseConflict> conflicts;
  int keepLocalCalls = 0;
  int useServerCalls = 0;

  @override
  Stream<List<GroupExpenseConflict>> watch({required String ownerKey}) =>
      Stream.value(conflicts);

  @override
  Future<void> keepLocalVersion(
    GroupExpenseConflict conflict, {
    required String ownerKey,
  }) async {
    keepLocalCalls += 1;
  }

  @override
  Future<void> useServerVersion(
    GroupExpenseConflict conflict, {
    required String ownerKey,
  }) async {
    useServerCalls += 1;
  }
}
