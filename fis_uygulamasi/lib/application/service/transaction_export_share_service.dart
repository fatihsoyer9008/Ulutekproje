import 'dart:convert';
import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum TransactionExportFormat {
  json,
  csv;

  String get label {
    switch (this) {
      case TransactionExportFormat.json:
        return 'JSON';
      case TransactionExportFormat.csv:
        return 'CSV';
    }
  }
}

typedef TemporaryDirectoryProvider = Future<Directory> Function();
typedef FileSharer = Future<void> Function(File file);
typedef FileDeleter = Future<void> Function(File file);
typedef DirectoryLister = Stream<FileSystemEntity> Function(Directory directory);

/// Kullanıcıya ait dosya sistemi ve paylaşım işlemlerini yürütür.
class TransactionExportShareService {
  TransactionExportShareService({
    required Future<String> Function() exportJson,
    required Future<String> Function() exportCsv,
    required TemporaryDirectoryProvider temporaryDirectory,
    required FileSharer shareFile,
    FileDeleter? deleteFile,
    DirectoryLister? listDirectory,
    DateTime Function()? now,
  }) : // Public parameter names intentionally differ from private fields.
       // ignore: prefer_initializing_formals
       _exportJson = exportJson,
       // ignore: prefer_initializing_formals
       _exportCsv = exportCsv,
       // ignore: prefer_initializing_formals
       _temporaryDirectory = temporaryDirectory,
       // ignore: prefer_initializing_formals
       _shareFile = shareFile,
       _deleteFile = deleteFile ?? _deleteFileStatic,
       _listDirectory = listDirectory ?? _listDirectoryStatic,
       _now = now ?? DateTime.now;

  final Future<String> Function() _exportJson;
  final Future<String> Function() _exportCsv;
  final TemporaryDirectoryProvider _temporaryDirectory;
  final FileSharer _shareFile;
  final FileDeleter _deleteFile;
  final DirectoryLister _listDirectory;
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

  /// Seçilen formata göre dışa aktarım dosyasını oluşturur.
  Future<File> createExportFile(
    TransactionExportFormat format,
  ) async {
    final content = format == TransactionExportFormat.json
        ? await _exportJson()
        : await _exportCsv();

    final directory = await _temporaryDirectory();

    final timestamp = _now()
        .toIso8601String()
        .replaceAll(':', '-');

    final extension =
        format == TransactionExportFormat.json ? 'json' : 'csv';

    final file = File(
      '${directory.path}/transactions_export_$timestamp.$extension',
    );

    await file.writeAsString(
      content,
      encoding: utf8,
    );

    return file;
  }

  /// Dosyayı oluşturur ve paylaşım ekranını açar.
  Future<void> exportAndShare(
    TransactionExportFormat format,
  ) async {
    await cleanupOldExportFiles();
    final file = await createExportFile(format);

    try {
      await _shareFile(file);
    } catch (error, stackTrace) {
      throw TransactionExportShareException(
        error,
        stackTrace,
      );
    } finally {
      try {
        if (await file.exists()) {
          await _deleteFile(file);
        }
      } catch (_) {
        // Cleanup must not mask the share result.
      }
    }
  }

  /// Eski export dosyalarını temizler.
Future<void> cleanupOldExportFiles([
    Directory? customDirectory,
  ]) async {
    try {
      final directory = customDirectory ?? await _temporaryDirectory();

      if (!await directory.exists()) {
        return;
      }

      await for (final entity in _listDirectory(directory)) {
        if (entity is File && entity.path.contains('transactions_export_')) {
          try {
            await _deleteFile(entity);
          } catch (_) {
            // Silinemeyen bireysel dosyaları atla.
          }
        }
      }
    } catch (_) {
      // Dizin bulunamazsa veya listeleme erişim hatası verirse sessizce yut.
    }
  }

  static Future<void> _deleteFileStatic(File file) => file.delete();

  static Stream<FileSystemEntity> _listDirectoryStatic(Directory directory) =>
      directory.list();

  static Future<void> _shareFileStatic(
    File file,
  ) async {
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
  TransactionExportShareException(
    this.cause,
    this.stackTrace,
  );

  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() =>
      'TransactionExportShareException: $cause';
}
