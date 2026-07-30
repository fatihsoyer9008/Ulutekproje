import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:finance_database/finance_database.dart';

const _maximumJsonFileSizeInBytes = 10 * 1024 * 1024;

typedef TransactionBatchImporter =
    Future<TransactionImportResult> Function(
      List<TransactionEntity> transactions,
    );
typedef TransactionJsonFilePicker = Future<TransactionJsonFile?> Function();

class TransactionJsonFile {
  const TransactionJsonFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

class TransactionImportPreview {
  TransactionImportPreview({
    required this.fileName,
    required List<TransactionEntity> transactions,
  }) : transactions = List.unmodifiable(transactions);

  final String fileName;
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
      if (!file.name.toLowerCase().endsWith('.json')) {
        throw const TransactionJsonImportException(
          'Lütfen .json uzantılı bir yedek dosyası seçin.',
        );
      }
      if (utf8.encode(file.contents).length > _maximumJsonFileSizeInBytes) {
        throw const TransactionJsonImportException(
          'Seçilen JSON dosyası 10 MB sınırını aşıyor.',
        );
      }

      return TransactionImportPreview(
        fileName: file.name,
        transactions: TransactionJsonBackup.decode(file.contents),
      );
    } on TransactionJsonImportException {
      rethrow;
    } on Exception catch (error) {
      throw TransactionJsonImportException('JSON yedeği okunamadı: $error');
    }
  }

  Future<TransactionImportResult> importBackup(
    TransactionImportPreview preview,
  ) => importTransactions(preview.transactions);
}

Future<TransactionJsonFile?> pickTransactionJsonFile() async {
  const typeGroup = XTypeGroup(
    label: 'JSON yedekleri',
    extensions: ['json'],
    mimeTypes: ['application/json', 'text/json'],
  );
  final file = await openFile(acceptedTypeGroups: [typeGroup]);
  if (file == null) return null;

  final length = await file.length();
  if (length > _maximumJsonFileSizeInBytes) {
    throw const TransactionJsonImportException(
      'Seçilen JSON dosyası 10 MB sınırını aşıyor.',
    );
  }
  return TransactionJsonFile(
    name: file.name,
    contents: await file.readAsString(),
  );
}
