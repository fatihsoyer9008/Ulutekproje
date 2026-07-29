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
      [TransactionEntitySchema],
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
        ..merchantName = 'Migros';

      final id = await repository.addTransaction(newTransaction);
      final fetched = await repository.getTransactionById(id);

      expect(fetched, isNotNull);
      expect(fetched?.id, equals(id));
      expect(fetched?.amountInMinor, equals(1250));
      expect(fetched?.merchantName, equals('Migros'));
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
        ..source = TransactionSource.manual;

      await repository.addTransaction(transaction);

      expect(await transactions.moveNext(), isTrue);
      expect(transactions.current, hasLength(1));
      expect(transactions.current.single.amountInMinor, 1250);
      expect(
        transactions.current.single.transactionType,
        TransactionType.income,
      );

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

    test('tarih aralığını gün sınırlarıyla filtreler ve azalan sıralar',
        () async {
      await repository.addTransaction(transaction(
        amountInMinor: 100,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 10),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 200,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 11, 23, 59, 59, 999),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 210,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 11, 23, 59, 59, 999, 999),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 10000,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 11, 12),
        transactionType: TransactionType.income,
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 300,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 12),
      ));

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
    });

    test('son yedi günün toplamlarını boş günler dahil döndürür', () async {
      await repository.addTransaction(transaction(
        amountInMinor: 1250,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 23, 9),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 250,
        category: TransactionCategory.ulasim,
        date: DateTime(2026, 7, 29, 18),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 50000,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 29, 10),
        transactionType: TransactionType.income,
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 999,
        category: TransactionCategory.fatura,
        date: DateTime(2026, 7, 22, 23),
      ));

      final totals = await repository.getWeeklyDailyTotals(
        referenceDate: DateTime(2026, 7, 29, 12),
      );

      expect(totals, hasLength(7));
      expect(totals[DateTime(2026, 7, 23)], equals(1250));
      expect(totals[DateTime(2026, 7, 29)], equals(250));
      expect(totals[DateTime(2026, 7, 24)], equals(0));
    });

    test('ayın kategori toplamlarını sadece ay içindeki işlemlerle hesaplar',
        () async {
      await repository.addTransaction(transaction(
        amountInMinor: 1000,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 1),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 500,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 29, 23),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 250,
        category: TransactionCategory.ulasim,
        date: DateTime(2026, 7, 15),
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 50000,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 15, 12),
        transactionType: TransactionType.income,
      ));
      await repository.addTransaction(transaction(
        amountInMinor: 900,
        category: TransactionCategory.fatura,
        date: DateTime(2026, 6, 30, 23),
      ));

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
    });
    
    test('başlangıç tarihi bitiş tarihinden sonra ise boş liste döndürmelidir', () async {
      await repository.addTransaction(transaction(
        amountInMinor: 5000,
        category: TransactionCategory.market,
        date: DateTime(2026, 7, 15),
      ));

      final results = await repository.getTransactionsBetween(
        DateTime(2026, 7, 29), // Start > End
        DateTime(2026, 7, 1),
      );

      expect(results, isEmpty);
    });

    test('boş veritabanında haftalık toplamlar 7 elemanlı ve tüm değerleri 0 dönmelidir', () async {
      final totals = await repository.getWeeklyDailyTotals(
        referenceDate: DateTime(2026, 7, 29),
      );

      expect(totals, hasLength(7));
      expect(totals.values.every((amount) => amount == 0), isTrue);
    });
  });
}
