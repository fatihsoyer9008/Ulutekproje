import 'dart:convert';

import 'package:isar/isar.dart';

import '../backup/transaction_json_backup.dart';
import '../models/offline_task.dart';
import '../models/receipt_entity.dart';
import '../models/receipt_line_item_entity.dart';
import '../models/transaction_entity.dart';

class TransactionRepository {
  /// Isar veritabanı örneği dışarıdan enjekte ediliyor (Dependency Injection)
  TransactionRepository(this._isar);

  final Isar _isar;

  /// Yeni bir işlemi veritabanına kaydeder.
  Future<Id> addTransaction(TransactionEntity transaction) async {
    final now = DateTime.now();
    transaction.createdAt = now;
    transaction.updatedAt = now;

    return _persistTransaction(transaction);
  }

  /// Transaction ve sync görevini aynı Isar transaction'ında kaydeder.
  /// Herhangi bir yazım hatasında iki kayıt da rollback edilir.
  Future<Id> addTransactionWithOfflineTask(
    TransactionEntity transaction, {
    required OfflineTask Function(TransactionEntity transaction)
    buildOfflineTask,
  }) async {
    final now = DateTime.now();
    transaction
      ..createdAt = now
      ..updatedAt = now;
    final task = buildOfflineTask(transaction)
      ..createdAt = now
      ..updatedAt = now;

    return _persistTransaction(transaction, offlineTask: task);
  }

  Future<int> countLocalOnlyTransactions() => _isar.transactionEntitys
      .filter()
      .syncStateEqualTo(SyncState.localOnly)
      .count();

  /// Eski yerel kayıtları kullanıcı onayından sonra atomik olarak
  /// senkronizasyon kuyruğuna alır. Yalnızca [localOnly] kayıtlar seçildiği
  /// için tekrar çalıştırmak aynı kayıt için ikinci görev oluşturmaz.
  Future<int> enqueueLocalOnlyTransactions({
    required String ownerKey,
    required String Function() createClientRecordId,
    required OfflineTask Function(TransactionEntity transaction)
    buildOfflineTask,
  }) async {
    return _isar.writeTxn(() async {
      final transactions = await _isar.transactionEntitys
          .filter()
          .syncStateEqualTo(SyncState.localOnly)
          .findAll();

      final now = DateTime.now();
      for (final transaction in transactions) {
        transaction
          ..clientRecordId =
              transaction.clientRecordId ?? createClientRecordId()
          ..ownerKey = ownerKey
          ..syncState = SyncState.pending
          ..updatedAt = now;
        await _isar.transactionEntitys.put(transaction);

        final task = buildOfflineTask(transaction)
          ..createdAt = now
          ..updatedAt = now;
        await _isar.offlineTasks.put(task);
      }
      return transactions.length;
    });
  }

  Future<Id> _persistTransaction(
    TransactionEntity transaction, {
    OfflineTask? offlineTask,
  }) async {
    return _isar.writeTxn(() async {
      final transactionId = await _isar.transactionEntitys.put(transaction);
      final receiptId = await _upsertReceipt(transactionId, transaction);
      await _replaceReceiptLineItems(
        transactionId,
        receiptId,
        transaction.receiptLineItems,
      );
      if (offlineTask != null) {
        await _isar.offlineTasks.put(offlineTask);
      }
      transaction.receiptLineItemsLoaded = true;
      return transactionId;
    });
  }

  /// Veritabanındaki tüm işlemleri getirir.
  Future<List<TransactionEntity>> getAllTransactions() async {
    final transactions = await _isar.transactionEntitys.where().findAll();
    return _hydrateReceiptLineItems(transactions);
  }

  /// Doğrulanmış bir JSON yedeğindeki işlemleri tek transaction'da içe aktarır.
  ///
  /// İçe aktarılan ID'ler kullanılmaz; böylece mevcut kayıtların üzerine
  /// yazılmaz. Aynı finansal işlem veritabanında veya seçilen dosyada birden
  /// fazla kez bulunuyorsa yalnızca ilk kayıt eklenir.
  Future<TransactionImportResult> importTransactions(
    List<TransactionEntity> transactions,
  ) async {
    if (transactions.isEmpty) {
      return const TransactionImportResult(
        selectedCount: 0,
        importedCount: 0,
        skippedDuplicateCount: 0,
      );
    }

    return await _isar.writeTxn(() async {
      final existing = await _isar.transactionEntitys.where().findAll();
      final fingerprints = existing.map(_fingerprint).toSet();
      final insertions = <TransactionEntity>[];
      var skippedDuplicateCount = 0;

      for (final transaction in transactions) {
        if (!fingerprints.add(_fingerprint(transaction))) {
          skippedDuplicateCount++;
          continue;
        }
        transaction.id = Isar.autoIncrement;
        insertions.add(transaction);
      }

      if (insertions.isNotEmpty) {
        final ids = await _isar.transactionEntitys.putAll(insertions);
        for (var index = 0; index < insertions.length; index++) {
          await _replaceReceiptLineItems(
            ids[index],
            await _upsertReceipt(ids[index], insertions[index]),
            insertions[index].receiptLineItems,
          );
          insertions[index].receiptLineItemsLoaded = true;
        }
      }

      return TransactionImportResult(
        selectedCount: transactions.length,
        importedCount: insertions.length,
        skippedDuplicateCount: skippedDuplicateCount,
      );
    });
  }

  /// Verilen tarih aralığındaki tüm işlemleri en yeniden en eskiye sıralar.
  ///
  /// Başlangıç tarihi günün başlangıcına genişletilir. Bitiş için sonraki günün
  /// başlangıcı exclusive üst sınır olarak kullanılır; bu, günün son
  /// milisaniyesinden sonraki mikro-saniyeli kayıtların da dahil edilmesini
  /// sağlar.
  Future<List<TransactionEntity>> getTransactionsBetween(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startOfDay = _startOfDay(startDate);
    final endOfDay = _startOfDay(endDate);

    if (endOfDay.isBefore(startOfDay)) {
      return const [];
    }

    final transactions = await _isar.transactionEntitys
        .filter()
        .dateBetween(startOfDay, _nextDayStart(endOfDay), includeUpper: false)
        .sortByDateDesc()
        .findAll();
    return _hydrateReceiptLineItems(transactions);
  }

  /// Verilen tarih aralığındaki yalnızca gider işlemlerini sıralı getirir.
  ///
  /// Bitiş günü, sonraki günün başlangıcı exclusive üst sınır kabul edilerek
  /// bütünüyle sorguya dahil edilir.
  Future<List<TransactionEntity>> getExpensesBetween(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startOfDay = _startOfDay(startDate);
    final endOfDay = _startOfDay(endDate);

    if (endOfDay.isBefore(startOfDay)) {
      return const [];
    }

    final transactions = await _isar.transactionEntitys
        .filter()
        .dateBetween(startOfDay, _nextDayStart(endOfDay), includeUpper: false)
        .and()
        .transactionTypeEqualTo(TransactionType.expense)
        .sortByDateDesc()
        .findAll();
    return _hydrateReceiptLineItems(transactions);
  }

  /// Son yedi günün günlük harcama toplamlarını kuruş cinsinden döndürür.
  ///
  /// [referenceDate] verilmezse bugünün tarihi kullanılır. Sonuç, referans
  /// günü dahil olmak üzere son yedi günün her biri için saat bilgisi sıfırlı
  /// bir tarih anahtarı içerir. Tutarlar yalnızca [int] ile toplanır.
  Future<Map<DateTime, int>> getWeeklyDailyTotals({
    DateTime? referenceDate,
  }) async {
    final referenceDay = _startOfDay(referenceDate ?? DateTime.now());
    final startDay = DateTime(
      referenceDay.year,
      referenceDay.month,
      referenceDay.day - 6,
    );
    final transactions = await getExpensesBetween(startDay, referenceDay);
    final totals = <DateTime, int>{
      for (
        var day = startDay;
        !day.isAfter(referenceDay);
        day = _nextDayStart(day)
      )
        day: 0,
    };

    for (final transaction in transactions) {
      final day = _startOfDay(transaction.date);
      totals[day] = (totals[day] ?? 0) + transaction.amountInMinor;
    }

    return totals;
  }

  /// İçinde bulunulan ayın kategori bazlı harcama toplamlarını döndürür.
  ///
  /// [referenceDate] verilmezse bugünün tarihi kullanılır. Sorgu, ayın ilk
  /// gününden referans gününün sonuna kadar olan işlemleri kapsar. Kategori
  /// alanı mevcut şemada null olamayan bir enum olduğundan, kategori adları
  /// enumun [TransactionCategory.name] değeriyle üretilir.
  Future<Map<TransactionCategory, int>> getCurrentMonthCategoryTotals({
    DateTime? referenceDate,
  }) async {
    final referenceDay = _startOfDay(referenceDate ?? DateTime.now());
    final startOfMonth = DateTime(referenceDay.year, referenceDay.month);
    final transactions = await getExpensesBetween(startOfMonth, referenceDay);
    final totals = <TransactionCategory, int>{};

    for (final transaction in transactions) {
      final category = transaction.category;
      totals[category] = (totals[category] ?? 0) + transaction.amountInMinor;
    }

    return totals;
  }

  /// Mevcut işlemleri ve veritabanındaki sonraki değişiklikleri yayınlar.
  Stream<List<TransactionEntity>> watchAllTransactions() {
    return _isar.transactionEntitys
        .where()
        .watch(fireImmediately: true)
        .asyncMap(_hydrateReceiptLineItems);
  }

  /// ID'ye göre tek bir işlemi getirir.
  Future<TransactionEntity?> getTransactionById(Id id) async {
    final transaction = await _isar.transactionEntitys.get(id);
    if (transaction == null) return null;
    transaction.receiptLineItems = await getReceiptLineItems(id);
    transaction.receiptLineItemsLoaded = true;
    return transaction;
  }

  /// İşleme ait fiş satırlarını fişteki sırasıyla getirir.
  Future<List<ReceiptLineItemEntity>> getReceiptLineItems(Id transactionId) =>
      _isar.receiptLineItemEntitys
          .filter()
          .transactionIdEqualTo(transactionId)
          .sortByPosition()
          .findAll();

  Future<ReceiptEntity?> getReceiptByTransactionId(Id transactionId) => _isar
      .receiptEntitys
      .filter()
      .transactionIdEqualTo(transactionId)
      .findFirst();

  /// Eski şemadan kalan ürün satırları için fiş oluşturur ve receiptId atar.
  Future<void> backfillReceiptLinks() async {
    final lineItems = await _isar.receiptLineItemEntitys.where().findAll();
    if (lineItems.isEmpty) return;

    await _isar.writeTxn(() async {
      final receiptIds = (await _isar.receiptEntitys.where().findAll())
          .map((receipt) => receipt.id)
          .toSet();
      final transactionIds = lineItems
          .where(
            (item) =>
                item.receiptId <= 0 || !receiptIds.contains(item.receiptId),
          )
          .map((item) => item.transactionId)
          .toSet();

      for (final transactionId in transactionIds) {
        final transaction = await _isar.transactionEntitys.get(transactionId);
        if (transaction == null) continue;

        final receiptId = await _upsertReceipt(
          transactionId,
          transaction,
          force: true,
        );
        if (receiptId == null) continue;

        final transactionItems = lineItems
            .where((item) => item.transactionId == transactionId)
            .toList();
        for (final item in transactionItems) {
          item.receiptId = receiptId;
        }
        await _isar.receiptLineItemEntitys.putAll(transactionItems);
      }
    });
  }

  /// Mevcut bir işlemi günceller.
  Future<void> updateTransaction(TransactionEntity transaction) async {
    transaction.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.transactionEntitys.put(transaction);
      final receiptId = await _upsertReceipt(transaction.id, transaction);
      if (transaction.receiptLineItemsLoaded) {
        await _replaceReceiptLineItems(
          transaction.id,
          receiptId,
          transaction.receiptLineItems,
        );
      }
    });
  }

  /// Verilen ID'ye sahip finansal işlemi veritabanından siler.
  Future<bool> deleteTransaction(Id id) async {
    return await _isar.writeTxn(() async {
      await _deleteReceiptLineItems(id);
      await _deleteReceipt(id);
      return await _isar.transactionEntitys.delete(id);
    });
  }

  Future<void> _replaceReceiptLineItems(
    Id transactionId,
    Id? receiptId,
    List<ReceiptLineItemEntity> items,
  ) async {
    await _deleteReceiptLineItems(transactionId);
    if (items.isEmpty) return;
    if (receiptId == null) {
      throw StateError('Ürün kalemleri bir fiş kaydı olmadan saklanamaz.');
    }

    for (var index = 0; index < items.length; index++) {
      items[index]
        ..id = Isar.autoIncrement
        ..transactionId = transactionId
        ..receiptId = receiptId
        ..position = index;
    }
    await _isar.receiptLineItemEntitys.putAll(items);
  }

  Future<void> _deleteReceiptLineItems(Id transactionId) async {
    await _isar.receiptLineItemEntitys
        .filter()
        .transactionIdEqualTo(transactionId)
        .deleteAll();
  }

  Future<Id?> _upsertReceipt(
    Id transactionId,
    TransactionEntity transaction, {
    bool force = false,
  }) async {
    final existing = await getReceiptByTransactionId(transactionId);
    final preserveUnloadedReceipt =
        existing != null && !transaction.receiptLineItemsLoaded;
    if (!force && !preserveUnloadedReceipt && !_hasReceipt(transaction)) {
      if (existing != null) await _isar.receiptEntitys.delete(existing.id);
      return null;
    }

    final now = DateTime.now();
    final receipt = existing ?? ReceiptEntity()
      ..createdAt = now;
    receipt
      ..transactionId = transactionId
      ..merchantName = transaction.merchantName
      ..totalAmountInMinor = transaction.amountInMinor
      ..date = transaction.date
      ..category = transaction.categoryName ?? transaction.category.name
      ..rawOcrText = transaction.rawOcrText
      ..updatedAt = now;
    return _isar.receiptEntitys.put(receipt);
  }

  Future<void> _deleteReceipt(Id transactionId) async {
    await _isar.receiptEntitys
        .filter()
        .transactionIdEqualTo(transactionId)
        .deleteAll();
  }

  bool _hasReceipt(TransactionEntity transaction) =>
      transaction.source != TransactionSource.manual ||
      transaction.rawOcrText?.trim().isNotEmpty == true ||
      transaction.receiptLineItems.isNotEmpty;

  Future<List<TransactionEntity>> _hydrateReceiptLineItems(
    List<TransactionEntity> transactions,
  ) async {
    if (transactions.isEmpty) return transactions;

    final transactionIds = transactions.map((item) => item.id).toSet();
    final lineItems = await _isar.receiptLineItemEntitys.where().findAll();
    final itemsByTransaction = <Id, List<ReceiptLineItemEntity>>{};
    for (final item in lineItems) {
      if (!transactionIds.contains(item.transactionId)) continue;
      (itemsByTransaction[item.transactionId] ??= []).add(item);
    }

    for (final transaction in transactions) {
      final items = itemsByTransaction[transaction.id] ?? [];
      items.sort((a, b) => a.position.compareTo(b.position));
      transaction
        ..receiptLineItems = items
        ..receiptLineItemsLoaded = true;
    }
    return transactions;
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _nextDayStart(DateTime date) =>
      _startOfDay(date).add(const Duration(days: 1));

  String _fingerprint(TransactionEntity transaction) => jsonEncode([
    transaction.transactionType.name,
    transaction.amountInMinor,
    transaction.category.name,
    transaction.date.toUtc().microsecondsSinceEpoch,
    transaction.merchantName,
    transaction.source.name,
    transaction.rawOcrText,
    transaction.note,
  ]);
}
