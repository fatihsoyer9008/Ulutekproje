import 'dart:convert';
import 'dart:io';

import 'package:app_main/application/service/transaction_export_share_service.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory tempDirectory;
  late Isar isar;
  late TransactionExportService databaseExporter;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDirectory = await Directory.systemTemp.createTemp('export_service_test_');
    isar = await Isar.open(
      [TransactionEntitySchema],
      directory: tempDirectory.path,
      name: 'export_service_test',
    );
    databaseExporter = TransactionExportService(isar);
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    await tempDirectory.delete(recursive: true);
  });

  setUp(() async {
    await isar.writeTxn(isar.clear);
  });

  TransactionEntity transaction({
    int amountInMinor = 1250,
    String? merchantName,
    String? rawOcrText,
    String? note,
  }) {
    return TransactionEntity()
      ..amountInMinor = amountInMinor
      ..category = TransactionCategory.market
      ..date = DateTime.utc(2026, 7, 30, 10)
      ..merchantName = merchantName
      ..source = TransactionSource.manual
      ..rawOcrText = rawOcrText
      ..note = note
      ..createdAt = DateTime.utc(2026, 7, 30, 10)
      ..updatedAt = DateTime.utc(2026, 7, 30, 10);
  }

  test('kuruş değerini kayıpsız tam sayı olarak dışa aktarır', () async {
    await isar.writeTxn(() => isar.transactionEntitys.put(transaction()));

    final json = jsonDecode(await databaseExporter.exportJsonString()) as List;

    expect(json.single['amountInMinor'], 1250);
    expect(json.single['amountInMinor'], isA<int>());
  });

  test('nullable alanları JSON null olarak korur', () async {
    await isar.writeTxn(() => isar.transactionEntitys.put(transaction()));

    final json = jsonDecode(await databaseExporter.exportJsonString()) as List;

    expect(json.single['merchantName'], isNull);
    expect(json.single['rawOcrText'], isNull);
    expect(json.single['note'], isNull);
  });

  test('Türkçe karakterleri UTF-8 JSON içinde bozulmadan korur', () async {
    const text = 'Şığ İÇÖÜ: çiğ köfte';
    await isar.writeTxn(
      () => isar.transactionEntitys.put(
        transaction(merchantName: text, note: text),
      ),
    );

    final json = jsonDecode(await databaseExporter.exportJsonString()) as List;

    expect(json.single['merchantName'], text);
    expect(json.single['note'], text);
  });

  test('boş veritabanında geçerli boş JSON dizisi üretir', () async {
    expect(await databaseExporter.exportJsonString(), '[]');
  });

  test('paylaşım hatasını uygulamaya özgü hata olarak bildirir', () async {
    final service = TransactionExportShareService(
      exportJson: () async => '[]',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (_) async => throw StateError('Paylaşım uygulaması yok'),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await expectLater(
      service.exportAndShareJson(),
      throwsA(
        isA<TransactionExportShareException>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
  });
}
