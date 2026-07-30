import 'dart:convert';
import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

typedef TemporaryDirectoryProvider = Future<Directory> Function();
typedef JsonFileSharer = Future<void> Function(File file);

/// Kullanıcıya ait dosya sistemi ve paylaşım işlemlerini yürütür.
class TransactionExportShareService {
  TransactionExportShareService({
    required this._exportJson,
    required this._temporaryDirectory,
    required this._shareFile,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<String> Function() _exportJson;
  final TemporaryDirectoryProvider _temporaryDirectory;
  final JsonFileSharer _shareFile;
  final DateTime Function() _now;

  /// Uygulamanın başlatırken açtığı Isar instance'ını kullanır.
  factory TransactionExportShareService.fromIsar(Isar isar) {
    final exporter = TransactionExportService(isar);
    return TransactionExportShareService(
      exportJson: exporter.exportJsonString,
      temporaryDirectory: getTemporaryDirectory,
      shareFile: _shareJsonFile,
    );
  }

  /// JSON dosyasını geçici klasöre oluşturur.
  Future<File> createExportFile() async {
    final json = await _exportJson();

    final directory = await _temporaryDirectory();

    final timestamp = _now().toIso8601String().replaceAll(':', '-');

    final file = File('${directory.path}/transactions_export_$timestamp.json');

    await file.writeAsString(json, encoding: utf8);

    return file;
  }

  /// JSON oluşturur ve paylaşım ekranını açar.
  Future<void> exportAndShareJson() async {
    final file = await createExportFile();

    try {
      await _shareFile(file);
    } catch (error, stackTrace) {
      throw TransactionExportShareException(error, stackTrace);
    }
  }

  static Future<void> _shareJsonFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Harcama Geçmişi (JSON)',
        text: 'Biz Finans harcama geçmişi yedeği',
      ),
    );
  }
}

class TransactionExportShareException implements Exception {
  TransactionExportShareException(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'TransactionExportShareException: $cause';
}
