import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:finance_database/finance_database.dart';

const _maximumBackupFileSizeInBytes = 10 * 1024 * 1024;

typedef TransactionBatchImporter =
    Future<TransactionImportResult> Function(
      List<TransactionEntity> transactions,
    );
typedef TransactionJsonFilePicker = Future<TransactionJsonFile?> Function();

enum TransactionImportFormat {
  json,
  csv;

  String get label => name.toUpperCase();
}

class TransactionJsonFile {
  const TransactionJsonFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

class TransactionImportPreview {
  TransactionImportPreview({
    required this.fileName,
    required this.format,
    required List<TransactionEntity> transactions,
  }) : transactions = List.unmodifiable(transactions);

  final String fileName;
  final TransactionImportFormat format;
  final List<TransactionEntity> transactions;
}

class TransactionJsonImportService {
  TransactionJsonImportService({
    required this.importTransactions,
    this.pickFile = pickTransactionJsonFile,
  });

  final TransactionBatchImporter importTransactions;
  final TransactionJsonFilePicker pickFile;

  Future<TransactionImportPreview?> selectBackup() async {
    try {
      final file = await pickFile();
      if (file == null) return null;
      final format = _formatForFileName(file.name);
      if (format == null) {
        throw const TransactionJsonImportException(
          'Lütfen .json veya .csv uzantılı bir yedek dosyası seçin.',
        );
      }
      if (utf8.encode(file.contents).length > _maximumBackupFileSizeInBytes) {
        throw const TransactionJsonImportException(
          'Seçilen yedek dosyası 10 MB sınırını aşıyor.',
        );
      }

      return TransactionImportPreview(
        fileName: file.name,
        format: format,
        transactions: format == TransactionImportFormat.json
            ? TransactionJsonBackup.decode(file.contents)
            : TransactionCsvBackup.decode(file.contents),
      );
    } on TransactionJsonImportException {
      rethrow;
    } on Exception catch (error) {
      throw TransactionJsonImportException('Yedek dosyası okunamadı: $error');
    }
  }

  Future<TransactionImportResult> importBackup(
    TransactionImportPreview preview,
  ) => importTransactions(preview.transactions);

  TransactionImportFormat? _formatForFileName(String fileName) {
    final lowerCaseName = fileName.toLowerCase();
    if (lowerCaseName.endsWith('.json')) return TransactionImportFormat.json;
    if (lowerCaseName.endsWith('.csv')) return TransactionImportFormat.csv;
    return null;
  }
}

Future<TransactionJsonFile?> pickTransactionJsonFile() async {
  const typeGroup = XTypeGroup(
    label: 'JSON ve CSV yedekleri',
    extensions: ['json', 'csv'],
    mimeTypes: ['application/json', 'text/json', 'text/csv'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return null;

  final length = await file.length();
  if (length > _maximumBackupFileSizeInBytes) {
    throw const TransactionJsonImportException(
      'Seçilen yedek dosyası 10 MB sınırını aşıyor.',
    );
  }
  return TransactionJsonFile(
    name: file.name,
    contents: await file.readAsString(),
  );
}
