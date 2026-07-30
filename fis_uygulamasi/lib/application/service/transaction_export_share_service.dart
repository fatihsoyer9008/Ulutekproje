import 'dart:convert';
import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum TransactionExportFormat { json, csv }

typedef TemporaryDirectoryProvider = Future<Directory> Function();
typedef FileSharer = Future<void> Function(File file);

/// Kullanıcıya ait dosya sistemi ve paylaşım işlemlerini yürütür.
class TransactionExportShareService {
  TransactionExportShareService({
    required Future<String> Function() exportJson,
    required Future<String> Function() exportCsv,
    required TemporaryDirectoryProvider temporaryDirectory,
    required FileSharer shareFile,
    DateTime Function()? now,
  })  : _exportJson = exportJson,
        _exportCsv = exportCsv,
        _temporaryDirectory = temporaryDirectory,
        _shareFile = shareFile,
        _now = now ?? DateTime.now;

  final Future<String> Function() _exportJson;
  final Future<String> Function() _exportCsv;
  final TemporaryDirectoryProvider _temporaryDirectory;
  final FileSharer _shareFile;
  final DateTime Function() _now;

  /// Uygulamanın başlatırken açtığı Isar instance'ını kullanır.
  factory TransactionExportShareService.fromIsar(Isar isar) {
    final exporter = TransactionExportService(isar);
    return TransactionExportShareService(
      exportJson: exporter.exportJsonString,
      exportCsv: exporter.exportCsvString,
      temporaryDirectory: getTemporaryDirectory,
      shareFile: _shareFileStatic,
    );
  }

  /// Seçilen formata göre dışa aktarım dosyasını geçici klasöre oluşturur.
  Future<File> createExportFile(TransactionExportFormat format) async {
    final content = format == TransactionExportFormat.json
        ? await _exportJson()
        : await _exportCsv();

    final directory = await _temporaryDirectory();
    final timestamp = _now().toIso8601String().replaceAll(':', '-');
    final extension = format == TransactionExportFormat.json ? 'json' : 'csv';

    final file = File('${directory.path}/transactions_export_$timestamp.$extension');

    await file.writeAsString(content, encoding: utf8);

    return file;
  }

  /// Seçilen formatta dosya oluşturur, paylaşım ekranını açar ve geçici dosyayı temizler.
  Future<void> exportAndShare(TransactionExportFormat format) async {
    final file = await createExportFile(format);

    try {
      await _shareFile(file);
    } catch (error, stackTrace) {
      throw TransactionExportShareException(error, stackTrace);
    } finally {
      // Paylaşım sonrası veya hata durumunda geçici dosyayı temizle
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Eski geçici dışa aktarım dosyalarını klasörden temizler.
  Future<void> cleanupOldExportFiles([Directory? customDirectory]) async {
    final directory = customDirectory ?? await _temporaryDirectory();
    if (!await directory.exists()) return;

    final entities = directory.listSync();
    for (final entity in entities) {
      if (entity is File &&
          (entity.path.contains('transactions_export_'))) {
        try {
          await entity.delete();
        } catch (_) {
          // Silinemeyen dosyalar için sessizce devam et
        }
      }
    }
  }

  static Future<void> _shareFileStatic(File file) async {
    final isJson = file.path.endsWith('.json');
    final formatLabel = isJson ? 'JSON' : 'CSV';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Harcama Geçmişi ($formatLabel)',
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