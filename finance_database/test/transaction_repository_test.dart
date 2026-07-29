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
}
