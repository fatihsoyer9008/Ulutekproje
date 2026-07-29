import 'package:isar/isar.dart';
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

    return await _isar.writeTxn(() async {
      return await _isar.transactionEntitys.put(transaction);
    });
  }

  /// Veritabanındaki tüm işlemleri getirir.
  Future<List<TransactionEntity>> getAllTransactions() async {
    return await _isar.transactionEntitys.where().findAll();
  }

  /// Verilen tarih aralığındaki işlemleri en yeniden en eskiye sıralı getirir.
  ///
  /// Başlangıç ve bitiş tarihleri, sırasıyla günün 00:00:00.000 ve
  /// 23:59:59.999 anlarına genişletilir; böylece sınır günlerdeki tüm işlemler
  /// sorguya dahil edilir.
  Future<List<TransactionEntity>> getTransactionsBetween(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startOfDay = _startOfDay(startDate);
    final endOfDay = _endOfDay(endDate);

    if (endOfDay.isBefore(startOfDay)) {
      return const [];
    }

    return await _isar.transactionEntitys
        .filter()
        .dateBetween(startOfDay, endOfDay)
        .sortByDateDesc()
        .findAll();
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
    final startDay = referenceDay.subtract(const Duration(days: 6));
    final transactions = await getTransactionsBetween(startDay, referenceDay);
    final totals = <DateTime, int>{
      for (var day = startDay;
          !day.isAfter(referenceDay);
          day = day.add(const Duration(days: 1)))
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
    final transactions = await getTransactionsBetween(startOfMonth, referenceDay);
    final totals = <TransactionCategory, int>{};

    for (final transaction in transactions) {
      final category = transaction.category;
      totals[category] = (totals[category] ?? 0) + transaction.amountInMinor;
    }

    return totals;
  }

  /// ID'ye göre tek bir işlemi getirir.
  Future<TransactionEntity?> getTransactionById(Id id) async {
    return await _isar.transactionEntitys.get(id);
  }

  /// Mevcut bir işlemi günceller.
  Future<void> updateTransaction(TransactionEntity transaction) async {
    transaction.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.transactionEntitys.put(transaction);
    });
  }

  /// Verilen ID'ye sahip finansal işlemi veritabanından siler.
  Future<bool> deleteTransaction(Id id) async {
    return await _isar.writeTxn(() async {
      return await _isar.transactionEntitys.delete(id);
    });
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}
