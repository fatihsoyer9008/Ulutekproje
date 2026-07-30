import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction_entity.dart';

class TransactionExportService {
  final Isar _isar;

  TransactionExportService(this._isar);

  /// Isar veritabanındaki tüm transaction kayıtlarını JSON String'e dönüştürür.
  Future<String> exportTransactionsToJson() async {
    final transactions = await _isar.transactionEntitys.where().findAll();

    if (transactions.isEmpty) {
      throw Exception('Dışa aktarılacak işlem bulunamadı.');
    }

    final List<Map<String, dynamic>> jsonList =
        transactions.map((transaction) => transaction.toJson()).toList();

    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// JSON verisini geçici klasöre kaydeder.
  Future<File> createExportFile() async {
    final jsonData = await exportTransactionsToJson();

    final tempDir = await getTemporaryDirectory();

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-');

    final file = File(
      '${tempDir.path}/transactions_export_$timestamp.json',
    );

    await file.writeAsString(
      jsonData,
      encoding: utf8,
    );

    return file;
  }

  /// JSON dosyasını oluşturur ve paylaşım ekranını açar.
  Future<void> exportAndShareJson() async {
    try {
      final file = await createExportFile();

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Harcama Geçmişi (JSON)',
        text: 'Biz Finans Harcama Geçmişi Yedeği',
      );
    } catch (_) {
      rethrow;
    }
  }
}