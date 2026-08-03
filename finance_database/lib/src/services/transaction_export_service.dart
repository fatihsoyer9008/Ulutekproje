import 'dart:convert';

import 'package:isar/isar.dart';

import '../backup/transaction_json_backup.dart';
import '../repository/transaction_repository.dart';

class TransactionExportService {
  final Isar _isar;

  TransactionExportService(this._isar);

  /// Isar veritabanındaki tüm işlem kayıtlarını JSON dizisine dönüştürür.
  ///
  /// Boş bir veritabanı geçerli bir JSON dizisi olan `[]` döndürür.
  Future<String> exportJsonString() async {
    final jsonList = await _transactionMaps();

    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': TransactionJsonBackup.supportedSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'transactions': jsonList,
    });
  }

  /// Excel tarafından UTF-8 olarak açılabilen CSV çıktısı üretir.
  ///
  /// UTF-8 BOM ve CRLF kullanımı, Türkçe karakterlerin Excel'de bozulmasını
  /// önler. `sep=;` satırı ve noktalı virgül ayıracı, Türkçe Excel bölge
  /// ayarlarında (ondalık ayıracı virgül) sütunların doğru ayrılmasını sağlar.
  /// Boş veritabanında yalnızca ayıracı tanımlayan satır ile başlık döner.
  Future<String> exportCsvString() async {
    final transactions = await _transactionMaps();
    final buffer = StringBuffer('\uFEFF');
    buffer.write('sep=;\r\n');
    buffer.write('${_csvRow(_headers)}\r\n');
    for (final transaction in transactions) {
      final values = _headers.map((header) => transaction[header]);
      buffer.write('${_csvRow(values)}\r\n');
    }
    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> _transactionMaps() async {
    final transactions = await TransactionRepository(
      _isar,
    ).getAllTransactions();
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

  String _csvRow(Iterable<Object?> values) => values.map(_csvValue).join(';');

  String _csvValue(Object? value) {
    var text = value?.toString() ?? '';
    // Excel, bu karakterlerle başlayan hücreleri formül olarak yorumlar.
    // Apostrof hücreyi metin olarak korur ve Excel'de görüntülenmez.
    if (text.startsWith(RegExp(r'[=+\-@]'))) text = "'$text";
    if (!text.contains(RegExp('[";\\r\\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
