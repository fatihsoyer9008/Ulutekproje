import 'dart:convert';

import 'package:isar/isar.dart';

import '../models/transaction_entity.dart';

class TransactionExportService {
  final Isar _isar;

  TransactionExportService(this._isar);

  /// Isar veritabanındaki tüm işlem kayıtlarını JSON dizisine dönüştürür.
  ///
  /// Boş bir veritabanı geçerli bir JSON dizisi olan `[]` döndürür.
  Future<String> exportJsonString() async {
    final transactions = await _isar.transactionEntitys.where().findAll();

    final List<Map<String, dynamic>> jsonList =
        transactions.map((transaction) => transaction.toJson()).toList();

    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }
}
