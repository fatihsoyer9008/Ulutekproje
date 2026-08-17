import 'dart:async';
import 'dart:io';

import 'package:app_main/core/database/database_providers.dart';
import 'package:app_main/features/groups/application/local_first_group_expense_reader.dart';
import 'package:app_main/features/groups/application/offline_first_group_expense_writer.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/data/group_repository.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../../fixtures/group_fixtures.dart';
import '../../fixtures/group_offline_operation_fixtures.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late GroupExpenseOfflineRepository local;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp(
      'local_first_group_expense_reader_test_',
    );
    isar = await Isar.open(
      [GroupExpenseEntitySchema, OfflineTaskSchema],
      directory: tempDirectory.path,
      name: 'local_first_group_expense_reader_test',
    );
    local = GroupExpenseOfflineRepository(isar);
  });

  setUp(() => isar.writeTxn(isar.clear));

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'remote refresh pending yerel kaydı korur ve yeni snapshotı ekler',
    () async {
      await OfflineFirstGroupExpenseWriter(
        local,
      ).save(groupExpenseCreateOperation);
      final remoteVersion = GroupExpense.fromJson(<String, Object?>{
        ...fastSplitTransferExpense.toJson(),
        'title': 'Sunucudaki eski başlık',
      });
      final reader = LocalFirstGroupExpenseReader(
        local,
        _GroupExpenseListRepository(<GroupExpense>[
          remoteVersion,
          itemizedMarketExpense,
        ]),
      );

      final applied = await reader.refresh(
        groupId: twoMemberGroupId,
        ownerKey: groupOperationOwnerKey,
      );
      final visible = await reader
          .watch(groupId: twoMemberGroupId, ownerKey: groupOperationOwnerKey)
          .first;

      expect(applied, 1);
      expect(visible, hasLength(2));
      expect(
        visible
            .singleWhere((expense) => expense.id == fastSplitTransferExpense.id)
            .title,
        fastSplitTransferExpense.title,
      );
      expect(
        visible.singleWhere(
          (expense) => expense.id == itemizedMarketExpense.id,
        ),
        isNotNull,
      );
    },
  );

  test(
    'provider remote yanıtı beklemeden yerel pending masrafı gösterir',
    () async {
      await OfflineFirstGroupExpenseWriter(
        local,
      ).save(groupExpenseCreateOperation);
      final remoteResult = Completer<List<GroupExpense>>();
      final container = ProviderContainer(
        overrides: <Override>[
          isarProvider.overrideWithValue(isar),
          currentGroupUserIdProvider.overrideWithValue(currentUserId),
          groupExpenseLocalFirstListingEnabledProvider.overrideWithValue(true),
          groupExpenseRepositoryProvider.overrideWithValue(
            _GroupExpenseListRepository.future(remoteResult.future),
          ),
        ],
      );
      addTearDown(container.dispose);

      final expenses = await container
          .read(groupExpensesProvider(twoMemberGroupId).future)
          .timeout(const Duration(seconds: 2));

      expect(expenses.map((expense) => expense.id), <String>[
        fastSplitTransferExpense.id,
      ]);
      remoteResult.complete(const <GroupExpense>[]);
      await remoteResult.future;
    },
  );

  test(
    'aktif watcher sonradan yazılan offline masrafı anında yayınlar',
    () async {
      final reader = LocalFirstGroupExpenseReader(
        local,
        _GroupExpenseListRepository(const <GroupExpense>[]),
      );
      final nextVisible = reader
          .watch(groupId: twoMemberGroupId, ownerKey: groupOperationOwnerKey)
          .firstWhere((expenses) => expenses.isNotEmpty);

      await OfflineFirstGroupExpenseWriter(
        local,
      ).save(groupExpenseCreateOperation);

      final visible = await nextVisible.timeout(const Duration(seconds: 2));
      expect(visible.single.id, fastSplitTransferExpense.id);
      expect(visible.single.title, fastSplitTransferExpense.title);
    },
  );
}

class _GroupExpenseListRepository implements GroupExpenseRepository {
  _GroupExpenseListRepository(List<GroupExpense> expenses)
    : _list = Future<List<GroupExpense>>.value(expenses);

  _GroupExpenseListRepository.future(this._list);

  final Future<List<GroupExpense>> _list;

  @override
  Future<List<GroupExpense>> listExpenses(String groupId) => _list;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
