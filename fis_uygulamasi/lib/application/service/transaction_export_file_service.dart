import 'dart:convert';
import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

enum TransactionExportFormat {
  json,
  csv;

  String get label => name.toUpperCase();

  String get extension => name;

  String get mimeType => this == json ? 'application/json' : 'text/csv';
}

typedef TemporaryDirectoryProvider = Future<Directory> Function();
typedef DocumentFileSaver = Future<String> Function(
  File file,
  String fileName,
  String mimeType,
);
typedef FileDeleter = Future<void> Function(File file);
typedef DirectoryLister =
    Stream<FileSystemEntity> Function(Directory directory);

class TransactionExportFileService {
  TransactionExportFileService({
    required Future<String> Function() exportJson,
    required Future<String> Function() exportCsv,
    required TemporaryDirectoryProvider temporaryDirectory,
    required DocumentFileSaver saveFile,
    FileDeleter? deleteFile,
    DirectoryLister? listDirectory,
    DateTime Function()? now,
  }) : _exportJson = exportJson,
       _exportCsv = exportCsv,
       _temporaryDirectory = temporaryDirectory,
       _saveFile = saveFile,
       _deleteFile = deleteFile ?? _deleteFileStatic,
       _listDirectory = listDirectory ?? _listDirectoryStatic,
       _now = now ?? DateTime.now;

  static const _documentsChannel = MethodChannel(
    'com.example.fis_uygulamasi/documents',
  );

  final Future<String> Function() _exportJson;
  final Future<String> Function() _exportCsv;
  final TemporaryDirectoryProvider _temporaryDirectory;
  final DocumentFileSaver _saveFile;
  final FileDeleter _deleteFile;
  final DirectoryLister _listDirectory;
  final DateTime Function() _now;

  factory TransactionExportFileService.fromIsar(Isar isar) {
    final exporter = TransactionExportService(isar);
    return TransactionExportFileService(
      exportJson: exporter.exportJsonString,
      exportCsv: exporter.exportCsvString,
      temporaryDirectory: getTemporaryDirectory,
      saveFile: _saveFileToDocuments,
    );
  }

  Future<File> createExportFile(TransactionExportFormat format) async {
    final content = format == TransactionExportFormat.json
        ? await _exportJson()
        : await _exportCsv();
    final directory = await _temporaryDirectory();
    final fileName = _fileName(format);
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  Future<String> exportAndSave(TransactionExportFormat format) async {
    await cleanupOldExportFiles();
    final file = await createExportFile(format);
    final fileName = file.uri.pathSegments.last;

    try {
      return await _saveFile(file, fileName, format.mimeType);
    } catch (error, stackTrace) {
      throw TransactionExportFileException(error, stackTrace);
    } finally {
      try {
        if (await file.exists()) await _deleteFile(file);
      } catch (_) {
        // Geçici dosya temizliği kayıt sonucunu maskelememeli.
      }
    }
  }

  Future<void> cleanupOldExportFiles([Directory? customDirectory]) async {
    try {
      final directory = customDirectory ?? await _temporaryDirectory();
      if (!await directory.exists()) return;

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
      // Dizin bulunamazsa veya listelenemezse kayıt akışını engelleme.
    }
  }

  String _fileName(TransactionExportFormat format) {
    final timestamp = _now().toIso8601String().replaceAll(':', '-');
    return 'transactions_export_$timestamp.${format.extension}';
  }

  static Future<String> _saveFileToDocuments(
    File file,
    String fileName,
    String mimeType,
  ) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Documents klasörüne doğrudan kayıt yalnızca Android üzerinde destekleniyor.',
      );
    }
    final savedName = await _documentsChannel.invokeMethod<String>(
      'saveFile',
      <String, String>{
        'sourcePath': file.path,
        'fileName': fileName,
        'mimeType': mimeType,
      },
    );
    if (savedName == null || savedName.isEmpty) {
      throw const FileSystemException('Dosya Documents klasörüne kaydedilemedi.');
    }
    return savedName;
  }

  static Future<void> _deleteFileStatic(File file) => file.delete();

  static Stream<FileSystemEntity> _listDirectoryStatic(Directory directory) =>
      directory.list();
}

class TransactionExportFileException implements Exception {
  TransactionExportFileException(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'TransactionExportFileException: $cause';
}
