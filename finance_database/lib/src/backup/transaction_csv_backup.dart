import 'dart:convert';

import '../models/transaction_entity.dart';
import 'transaction_json_backup.dart';

abstract final class TransactionCsvBackup {
  static const _requiredHeaders = <String>{
    'transactionType',
    'amountInMinor',
    'category',
    'date',
    'source',
  };

  static List<TransactionEntity> decode(String source) {
    final rows = _parseRows(source);
    if (rows.isEmpty) {
      throw const TransactionJsonImportException(
        'CSV dosyasında başlık satırı bulunamadı.',
      );
    }

    var headerIndex = 0;
    if ((rows.first.length == 1 && rows.first.single.trim() == 'sep=;') ||
        (rows.first.length == 2 &&
            rows.first.first.trim() == 'sep=' &&
            rows.first.last.isEmpty)) {
      headerIndex = 1;
    }
    if (rows.length <= headerIndex) {
      throw const TransactionJsonImportException(
        'CSV dosyasında başlık satırı bulunamadı.',
      );
    }

    final headers = rows[headerIndex].map((value) => value.trim()).toList();
    final missingHeaders = _requiredHeaders.difference(headers.toSet());
    if (missingHeaders.isNotEmpty) {
      throw TransactionJsonImportException(
        'CSV dosyasında zorunlu alanlar eksik: ${missingHeaders.join(', ')}.',
      );
    }

    final transactions = <Map<String, dynamic>>[];
    for (var index = headerIndex + 1; index < rows.length; index++) {
      final values = rows[index];
      if (values.every((value) => value.isEmpty)) continue;
      if (values.length != headers.length) {
        throw TransactionJsonImportException(
          '${index - headerIndex}. CSV satırındaki sütun sayısı geçersiz.',
        );
      }

      final transaction = <String, dynamic>{};
      for (var column = 0; column < headers.length; column++) {
        final header = headers[column];
        var value = values[column];
        if (value.startsWith("'") &&
            value.length > 1 &&
            '=+-@'.contains(value[1])) {
          value = value.substring(1);
        }
        if (value.isEmpty) continue;
        transaction[header] = header == 'amountInMinor'
            ? int.tryParse(value) ?? value
            : value;
      }
      transactions.add(transaction);
    }

    return TransactionJsonBackup.decode(jsonEncode(transactions));
  }

  static List<List<String>> _parseRows(String source) {
    final input = source.startsWith('\uFEFF') ? source.substring(1) : source;
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (character == '"') {
        if (inQuotes && index + 1 < input.length && input[index + 1] == '"') {
          field.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (character == ';' && !inQuotes) {
        row.add(field.toString());
        field = StringBuffer();
      } else if ((character == '\r' || character == '\n') && !inQuotes) {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        row.add(field.toString());
        rows.add(row);
        row = <String>[];
        field = StringBuffer();
      } else {
        field.write(character);
      }
    }

    if (inQuotes) {
      throw const TransactionJsonImportException(
        'CSV dosyasında kapanmamış tırnaklı bir alan var.',
      );
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
