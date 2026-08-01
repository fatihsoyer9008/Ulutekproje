import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
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
typedef PlatformFileSaver =
    Future<String> Function(File file, String fileName, String mimeType);
typedef DocumentFileSaver =
    Future<TransactionExportSaveResult> Function(
      File file,
      String fileName,
      String mimeType,
    );
typedef FileDeleter = Future<void> Function(File file);
typedef DirectoryLister =
    Stream<FileSystemEntity> Function(Directory directory);

enum TransactionExportPlatform { android, ios, other }

enum TransactionExportSaveDestination {
  documents,
  shareSheet,
  selectedLocation,
}

class TransactionExportSaveResult {
  const TransactionExportSaveResult.documents(this.displayValue)
    : destination = TransactionExportSaveDestination.documents;

  const TransactionExportSaveResult.shared(this.displayValue)
    : destination = TransactionExportSaveDestination.shareSheet;

  const TransactionExportSaveResult.selectedLocation(this.displayValue)
    : destination = TransactionExportSaveDestination.selectedLocation;

  final TransactionExportSaveDestination destination;
  final String displayValue;
}

const _documentsChannel = MethodChannel('com.example.fis_uygulamasi/documents');

Future<TransactionExportSaveResult> saveTransactionExportFile(
  File file,
  String fileName,
  String mimeType, {
  TransactionExportPlatform? platform,
  PlatformFileSaver? androidSaver,
  PlatformFileSaver? iosShareFallback,
  PlatformFileSaver? saveDialogFallback,
}) async {
  final effectivePlatform = platform ?? _currentExportPlatform();
  switch (effectivePlatform) {
    case TransactionExportPlatform.android:
      final savedName = await (androidSaver ?? _saveFileToAndroidDocuments)(
        file,
        fileName,
        mimeType,
      );
      return TransactionExportSaveResult.documents(savedName);
    case TransactionExportPlatform.ios:
      final sharedName = await (iosShareFallback ?? _shareFileOnIOS)(
        file,
        fileName,
        mimeType,
      );
      return TransactionExportSaveResult.shared(sharedName);
    case TransactionExportPlatform.other:
      final location = await (saveDialogFallback ?? _saveFileWithDialog)(
        file,
        fileName,
        mimeType,
      );
      return TransactionExportSaveResult.selectedLocation(location);
  }
}

class TransactionExportFileService {
  factory TransactionExportFileService({
    required Future<String> Function() exportJson,
    required Future<String> Function() exportCsv,
    required TemporaryDirectoryProvider temporaryDirectory,
    required DocumentFileSaver saveFile,
    FileDeleter? deleteFile,
    DirectoryLister? listDirectory,
    DateTime Function()? now,
  }) => TransactionExportFileService._(
    exportJson,
    exportCsv,
    temporaryDirectory,
    saveFile,
    deleteFile: deleteFile,
    listDirectory: listDirectory,
    now: now,
  );

  TransactionExportFileService._(
    this._exportJson,
    this._exportCsv,
    this._temporaryDirectory,
    this._saveFile, {
    FileDeleter? deleteFile,
    DirectoryLister? listDirectory,
    DateTime Function()? now,
  }) : _deleteFile = deleteFile ?? _deleteFileStatic,
       _listDirectory = listDirectory ?? _listDirectoryStatic,
       _now = now ?? DateTime.now;

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
      saveFile: saveTransactionExportFile,
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

  Future<TransactionExportSaveResult> exportAndSave(
    TransactionExportFormat format,
  ) async {
    await cleanupOldExportFiles();
    final file = await createExportFile(format);
    final fileName = file.uri.pathSegments.last;

    try {
      return await _saveFile(file, fileName, format.mimeType);
    } on TransactionExportCancelledException {
      rethrow;
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

  static Future<void> _deleteFileStatic(File file) => file.delete();

  static Stream<FileSystemEntity> _listDirectoryStatic(Directory directory) =>
      directory.list();
}

TransactionExportPlatform _currentExportPlatform() {
  if (Platform.isAndroid) return TransactionExportPlatform.android;
  if (Platform.isIOS) return TransactionExportPlatform.ios;
  return TransactionExportPlatform.other;
}

Future<String> _saveFileToAndroidDocuments(
  File file,
  String fileName,
  String mimeType,
) async {
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

Future<String> _shareFileOnIOS(
  File file,
  String fileName,
  String mimeType,
) async {
  String? sharedName;
  try {
    sharedName = await _documentsChannel.invokeMethod<String>(
      'shareFile',
      <String, String>{
        'sourcePath': file.path,
        'fileName': fileName,
        'mimeType': mimeType,
      },
    );
  } on PlatformException catch (error) {
    if (error.code == 'share_cancelled') {
      throw const TransactionExportCancelledException();
    }
    rethrow;
  }
  if (sharedName == null || sharedName.isEmpty) {
    throw const FileSystemException('Dosya paylaşılamadı.');
  }
  return sharedName;
}

Future<String> _saveFileWithDialog(
  File file,
  String fileName,
  String mimeType,
) async {
  final location = await getSaveLocation(suggestedName: fileName);
  if (location == null) {
    throw const TransactionExportCancelledException();
  }
  await XFile(
    file.path,
    name: fileName,
    mimeType: mimeType,
  ).saveTo(location.path);
  return location.path;
}

class TransactionExportFileException implements Exception {
  TransactionExportFileException(this.cause, this.stackTrace);

  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'TransactionExportFileException: $cause';
}

class TransactionExportCancelledException implements Exception {
  const TransactionExportCancelledException();
}
