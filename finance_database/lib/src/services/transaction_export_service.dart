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
    final jsonList = await _transactionMaps();

    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  /// Excel tarafından UTF-8 olarak açılabilen CSV çıktısı üretir.
  ///
  /// UTF-8 BOM ve CRLF kullanımı, Türkçe karakterlerin Excel'de bozulmasını
  /// önler. Boş veritabanında yalnızca başlık satırı döner.
  Future<String> exportCsvString() async {
    final transactions = await _transactionMaps();
    final buffer = StringBuffer('\uFEFF');
    buffer.write('${_csvRow(_headers)}\r\n');
    for (final transaction in transactions) {
      final values = _headers.map((header) => transaction[header]);
      buffer.write('${_csvRow(values)}\r\n');
    }
    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> _transactionMaps() async {
    final transactions = await _isar.transactionEntitys.where().findAll();
    return transactions.map((transaction) => transaction.toJson()).toList();
  }

  static const _headers = <String>[
    'id',
    'transactionType',
    'amountInMinor',
    'category',
    'date',
    'merchantName',
    'source',
    'rawOcrText',
    'note',
    'createdAt',
    'updatedAt',
  ];

  String _csvRow(Iterable<Object?> values) => values.map(_csvValue).join(',');

  String _csvValue(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.contains(RegExp('[",\\r\\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
