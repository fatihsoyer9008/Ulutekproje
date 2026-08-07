import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

// Projenin barrel/export dosyası ve modelleri
import 'package:finance_database/finance_database.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late TransactionRepository repository;

  // 1. TÜM TESTLER BAŞLAMADAN ÖNCE (setUpAll)
  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);

    // İşletim sisteminin geçici (temp) dizininde benzersiz bir klasör oluşturur
    tempDir = await Directory.systemTemp.createTemp('isar_repository_test_');

    // Isar, IsarService'e bağımlı olmadan doğrudan geçici klasörde açılır
    isar = await Isar.open(
      [
        TransactionEntitySchema,
        ReceiptEntitySchema,
        ReceiptLineItemEntitySchema,
        OfflineTaskSchema,
      ],
      directory: tempDir.path,
      name: 'transaction_repository_test',
    );

    // Repository, dışarıdan (Dependency Injection) Isar instance'ını alır
    repository = TransactionRepository(isar);
  });

  // 2. TÜM TESTLER BİTTİKTEN SONRA (tearDownAll)
  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // 3. HER BİR TEST TEK TEK ÇALIŞMADAN ÖNCE (setUp)
  setUp(() async {
    await isar.writeTxn(() async {
      await isar.clear();
    });
  });

  // 4. TEST SENARYOLARI (CRUD)
  group('TransactionRepository CRUD Testleri', () {
    // Test 1: Ekleme & ID ile Getirme
    test('Transaction ekleme ve ID ile getirme senaryosu', () async {
      final newTransaction = TransactionEntity()
        ..amountInMinor =
            1250 // 12.50 TL
        ..category = TransactionCategory.market
        ..date = DateTime.now()
        ..source = TransactionSource.manual
        ..clientRecordId = 'd9ca5a3e-599d-497c-8c96-c68c0e5b90d1'
        ..ownerKey = 'guest:test-installation'
        ..syncState = SyncState.pending
        ..merchantName = 'Migros';

      final id = await repository.addTransaction(newTransaction);
      final fetched = await repository.getTransactionById(id);

      expect(fetched, isNotNull);
      expect(fetched?.id, equals(id));
      expect(fetched?.amountInMinor, equals(1250));
      expect(fetched?.merchantName, equals('Migros'));
      expect(
        fetched?.clientRecordId,
        equals('d9ca5a3e-599d-497c-8c96-c68c0e5b90d1'),
      );
      expect(fetched?.ownerKey, equals('guest:test-installation'));
      expect(fetched?.syncState, SyncState.pending);
    });

    test('yeni işlem varsayılan olarak localOnly durumundadır', () {
      final transaction = TransactionEntity();

      expect(transaction.syncState, SyncState.localOnly);
    });

    test('transaction ve offline task atomik olarak kaydedilir', () async {
      final transaction = TransactionEntity()
        ..amountInMinor = 2500
        ..category = TransactionCategory.market
        ..date = DateTime(2026, 8, 5)
        ..source = TransactionSource.manual
        ..clientRecordId = 'd9ca5a3e-599d-497c-8c96-c68c0e5b90d1'
        ..ownerKey = 'user:test-user'
        ..syncState = SyncState.pending;

      final id = await repository.addTransactionWithOfflineTask(
        transaction,
        buildOfflineTask: (_) => OfflineTask()
          ..clientTaskId = 'operation-atomic-success'
          ..payloadJson = '{}',
      );

      expect(await repository.getTransactionById(id), isNotNull);
      final tasks = await isar.offlineTasks.where().findAll();
      expect(tasks, hasLength(1));
      expect(tasks.single.clientTaskId, 'operation-atomic-success');
      expect(tasks.single.createdAt, transaction.createdAt);
    });

    test('localOnly kayıtları idempotent biçimde sync kuyruğuna alır', () async {
      final transaction = TransactionEntity()
        ..amountInMinor = 4200
        ..category = TransactionCategory.market
        ..date = DateTime(2026, 8, 6)
        ..source = TransactionSource.manual;
      await repository.addTransaction(transaction);

      var recordSequence = 0;
      var taskSequence = 0;
      Future<int> claim() => repository.enqueueLocalOnlyTransactions(
        ownerKey: 'user:test-user',
        createClientRecordId: () => 'record-${recordSequence++}',
        buildOfflineTask: (_) => OfflineTask()
          ..clientTaskId = 'task-${taskSequence++}'
          ..payloadJson = '{}',
      );

      expect(await repository.countLocalOnlyTransactions(), 1);
      expect(await claim(), 1);
      expect(await claim(), 0);

      final stored = await repository.getTransactionById(transaction.id);
      expect(stored?.ownerKey, 'user:test-user');
      expect(stored?.clientRecordId, 'record-0');
      expect(stored?.syncState, SyncState.pending);
      expect(await isar.offlineTasks.count(), 1);
    });

    test(
      'offline task yazımı hata verirse transaction rollback edilir',
      () async {
        final existingTask = OfflineTask()
          ..clientTaskId = 'duplicate-operation-id'
          ..payloadJson = '{}'
          ..createdAt = DateTime(2026, 8, 5)
          ..updatedAt = DateTime(2026, 8, 5);
        await isar.writeTxn(() => isar.offlineTasks.put(existingTask));
        final transaction = TransactionEntity()
          ..amountInMinor = 2500
          ..category = TransactionCategory.market
          ..date = DateTime(2026, 8, 5)
          ..source = TransactionSource.manual;

        await expectLater(
          repository.addTransactionWithOfflineTask(
            transaction,
            buildOfflineTask: (_) => OfflineTask()
              ..clientTaskId = 'duplicate-operation-id'
              ..payloadJson = '{}',
          ),
          throwsA(anything),
        );

        expect(await isar.transactionEntitys.count(), 0);
        expect(await isar.offlineTasks.count(), 1);
      },
    );

    test('eski metadata alanları null olan kaydı sorunsuz okur', () async {
      final legacyTransaction = TransactionEntity()
        ..amountInMinor = 9900
        ..category = TransactionCategory.diger
        ..date = DateTime(2026, 8, 5)
        ..source = TransactionSource.manual;

      final id = await repository.addTransaction(legacyTransaction);
      final fetched = await repository.getTransactionById(id);

      expect(fetched, isNotNull);
      expect(fetched?.clientRecordId, isNull);
      expect(fetched?.ownerKey, isNull);
      expect(fetched?.syncState, SyncState.localOnly);
    });

    // Test 2: Tüm Kayıtları Getirme
    test('Tüm transaction kayıtlarını getirme senaryosu', () async {
      final t1 = TransactionEntity()
        ..amountInMinor = 50000
        ..category = TransactionCategory.fatura
        ..date = DateTime.now()
        ..source = TransactionSource.manual;

      final t2 = TransactionEntity()
        ..amountInMinor = 2500
        ..category = TransactionCategory.ulasim
        ..date = DateTime.now()
        ..source = TransactionSource.ocrRegex;

      await repository.addTransaction(t1);
      await repository.addTransaction(t2);

      final list = await repository.getAllTransactions();

      expect(list.length, equals(2));
    });

    test('Yeni kayıtları stream üzerinden anlık yayınlar', () async {
      final transactions = StreamIterator(repository.watchAllTransactions());

      expect(await transactions.moveNext(), isTrue);
      expect(transactions.current, isEmpty);

      final transaction = TransactionEntity()
        ..transactionType = TransactionType.income
        ..amountInMinor = 1250
        ..category = TransactionCategory.market
        ..date = DateTime.now()
        ..source = TransactionSource.manual
        ..receiptLineItems = [
          ReceiptLineItemEntity()
            ..transactionId = 0
            ..position = 0
            ..name = 'Maaş kalemi',
        ]
        ..receiptLineItemsLoaded = true;

      await repository.addTransaction(transaction);

      expect(await transactions.moveNext(), isTrue);
      expect(transactions.current, hasLength(1));
      expect(transactions.current.single.amountInMinor, 1250);
      expect(
        transactions.current.single.transactionType,
        TransactionType.income,
      );
      expect(transactions.current.single.receiptLineItems, hasLength(1));

      await transactions.cancel();
    });

    // Test 3: Güncelleme
    test('Transaction güncelleme senaryosu', () async {
      final transaction = TransactionEntity()
        ..amountInMinor = 1000
        ..category = TransactionCategory.diger
        ..date = DateTime.now()
        ..source = TransactionSource.manual
        ..merchantName = 'Eski Mağaza';

      final id = await repository.addTransaction(transaction);

      final existing = await repository.getTransactionById(id);
      expect(existing, isNotNull);

      existing!.merchantName = 'Yeni Mağaza';
      existing.amountInMinor = 2000;
      await repository.updateTransaction(existing);

      final updated = await repository.getTransactionById(id);
      expect(updated?.merchantName, equals('Yeni Mağaza'));
      expect(updated?.amountInMinor, equals(2000));
    });

    // Test 4: Silme
    test('Transaction silme senaryosu', () async {
      final transaction = TransactionEntity()
        ..amountInMinor = 3000
        ..category = TransactionCategory.eglence
        ..date = DateTime.now()
        ..source = TransactionSource.manual;

      final id = await repository.addTransaction(transaction);

      final isDeleted = await repository.deleteTransaction(id);
      expect(isDeleted, isTrue);

      final fetched = await repository.getTransactionById(id);
      expect(fetched, isNull);
    });

    test(
      'ürünleri yüklenmemiş entity güncellenince mevcut ürünleri korur',
      () async {
        final transaction = TransactionDraft(
          institutionName: 'Migros',
          category: 'Market',
          amountInMinor: 2500,
          receiptItems: const [ReceiptItem(name: 'Süt', priceMinor: 2500)],
        ).toTransactionEntity();
        final id = await repository.addTransaction(transaction);
        final receiptBeforeUpdate = await repository.getReceiptByTransactionId(
          id,
        );

        final unloaded = await isar.transactionEntitys.get(id);
        expect(unloaded?.receiptLineItemsLoaded, isFalse);
        unloaded!.merchantName = 'Migros Jet';
        await repository.updateTransaction(unloaded);

        final updated = await repository.getTransactionById(id);
        final receiptAfterUpdate = await repository.getReceiptByTransactionId(
          id,
        );
        expect(updated?.merchantName, 'Migros Jet');
        expect(receiptAfterUpdate?.id, receiptBeforeUpdate?.id);
        expect(
          updated?.receiptLineItems.single.receiptId,
          receiptAfterUpdate?.id,
        );
        expect(updated?.receiptLineItems.single.name, 'Süt');
      },
    );

    test('fiş ürünlerini işlemle birlikte kaydeder ve siler', () async {
      final transaction = TransactionDraft(
        institutionName: 'Migros',
        category: 'Market',
        amountInMinor: 4500,
        receiptItems: const [
          ReceiptItem(
            name: 'Süt',
            quantity: 2,
            unitPriceInMinor: 1500,
            totalAmountInMinor: 3000,
          ),
          ReceiptItem(name: 'Ekmek', priceMinor: 1500),
        ],
      ).toTransactionEntity();

      final id = await repository.addTransaction(transaction);
      final items = await repository.getReceiptLineItems(id);
      final receipt = await repository.getReceiptByTransactionId(id);

      expect(items.map((item) => item.name), ['Süt', 'Ekmek']);
      expect(items.first.transactionId, id);
      expect(receipt?.transactionId, id);
      expect(receipt?.totalAmountInMinor, 4500);
      expect(items.first.receiptId, receipt?.id);
      expect(items.first.quantity, 2);
      expect(items.first.unitPriceInMinor, 1500);
      expect(
        (await repository.getTransactionById(id))?.receiptLineItems,
        hasLength(2),
      );

      await repository.deleteTransaction(id);
      expect(await repository.getReceiptByTransactionId(id), isNull);
      expect(await repository.getReceiptLineItems(id), isEmpty);
    });

    test('ürün kaydı hata verirse işlem, fiş ve ürünleri geri alır', () async {
      final transaction = TransactionEntity()
        ..amountInMinor = 1000
        ..category = TransactionCategory.market
        ..date = DateTime(2026, 8, 4)
        ..source = TransactionSource.ocrLlm
        ..receiptLineItems = [
          ReceiptLineItemEntity()
            ..transactionId = 0
            ..receiptId = 0
            ..position = 0,
        ]
        ..receiptLineItemsLoaded = true;

      await expectLater(
        repository.addTransaction(transaction),
        throwsA(anything),
      );

      expect(await isar.transactionEntitys.count(), 0);
      expect(await isar.receiptEntitys.count(), 0);
      expect(await isar.receiptLineItemEntitys.count(), 0);
    });
  });
  group('TransactionRepository analiz sorguları', () {
    TransactionEntity transaction({
      required int amountInMinor,
      required TransactionCategory category,
      required DateTime date,
      TransactionType transactionType = TransactionType.expense,
    }) {
      return TransactionEntity()
        ..transactionType = transactionType
        ..amountInMinor = amountInMinor
        ..category = category
        ..date = date
        ..source = TransactionSource.manual;
    }

    test(
      'tarih aralığını gün sınırlarıyla filtreler ve azalan sıralar',
      () async {
        await repository.addTransaction(
          transaction(
            amountInMinor: 100,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 10),
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 200,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 11, 23, 59, 59, 999),
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 210,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 11, 23, 59, 59, 999, 999),
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 10000,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 11, 12),
            transactionType: TransactionType.income,
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 300,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 12),
          ),
        );

        final results = await repository.getTransactionsBetween(
          DateTime(2026, 7, 10, 14),
          DateTime(2026, 7, 11, 8),
        );

        expect(
          results.map((item) => item.amountInMinor).toList(),
          equals([210, 200, 10000, 100]),
        );

        final expenses = await repository.getExpensesBetween(
          DateTime(2026, 7, 10, 14),
          DateTime(2026, 7, 11, 8),
        );

        expect(
          expenses.map((item) => item.amountInMinor).toList(),
          equals([210, 200, 100]),
        );
      },
    );

    test('son yedi günün toplamlarını boş günler dahil döndürür', () async {
      await repository.addTransaction(
        transaction(
          amountInMinor: 1250,
          category: TransactionCategory.market,
          date: DateTime(2026, 7, 23, 9),
        ),
      );
      await repository.addTransaction(
        transaction(
          amountInMinor: 250,
          category: TransactionCategory.ulasim,
          date: DateTime(2026, 7, 29, 18),
        ),
      );
      await repository.addTransaction(
        transaction(
          amountInMinor: 50000,
          category: TransactionCategory.market,
          date: DateTime(2026, 7, 29, 10),
          transactionType: TransactionType.income,
        ),
      );
      await repository.addTransaction(
        transaction(
          amountInMinor: 999,
          category: TransactionCategory.fatura,
          date: DateTime(2026, 7, 22, 23),
        ),
      );

      final totals = await repository.getWeeklyDailyTotals(
        referenceDate: DateTime(2026, 7, 29, 12),
      );

      expect(totals, hasLength(7));
      expect(totals[DateTime(2026, 7, 23)], equals(1250));
      expect(totals[DateTime(2026, 7, 29)], equals(250));
      expect(totals[DateTime(2026, 7, 24)], equals(0));
    });

    test(
      'ayın kategori toplamlarını sadece ay içindeki işlemlerle hesaplar',
      () async {
        await repository.addTransaction(
          transaction(
            amountInMinor: 1000,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 1),
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 500,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 29, 23),
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 250,
            category: TransactionCategory.ulasim,
            date: DateTime(2026, 7, 15),
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 50000,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 15, 12),
            transactionType: TransactionType.income,
          ),
        );
        await repository.addTransaction(
          transaction(
            amountInMinor: 900,
            category: TransactionCategory.fatura,
            date: DateTime(2026, 6, 30, 23),
          ),
        );

        final totals = await repository.getCurrentMonthCategoryTotals(
          referenceDate: DateTime(2026, 7, 29),
        );

        expect(
          totals,
          equals({
            TransactionCategory.market: 1500,
            TransactionCategory.ulasim: 250,
          }),
        );
      },
    );

    test(
      'başlangıç tarihi bitiş tarihinden sonra ise boş liste döndürmelidir',
      () async {
        await repository.addTransaction(
          transaction(
            amountInMinor: 5000,
            category: TransactionCategory.market,
            date: DateTime(2026, 7, 15),
          ),
        );

        final results = await repository.getTransactionsBetween(
          DateTime(2026, 7, 29), // Start > End
          DateTime(2026, 7, 1),
        );

        expect(results, isEmpty);
      },
    );

    test(
      'boş veritabanında haftalık toplamlar 7 elemanlı ve tüm değerleri 0 dönmelidir',
      () async {
        final totals = await repository.getWeeklyDailyTotals(
          referenceDate: DateTime(2026, 7, 29),
        );

        expect(totals, hasLength(7));
        expect(totals.values.every((amount) => amount == 0), isTrue);
      },
    );
  });
}
