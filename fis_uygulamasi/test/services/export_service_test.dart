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
    tempDirectory = await Directory.systemTemp.createTemp(
      'export_service_test_',
    );
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
    TransactionType transactionType = TransactionType.expense,
    TransactionCategory category = TransactionCategory.market,
    TransactionSource source = TransactionSource.manual,
    String? merchantName,
    String? rawOcrText,
    String? note,
  }) {
    return TransactionEntity()
      ..amountInMinor = amountInMinor
      ..transactionType = transactionType
      ..category = category
      ..date = DateTime.utc(2026, 7, 30, 10)
      ..merchantName = merchantName
      ..source = source
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

  test('tüm alanları ve çoklu transaction kayıtlarını dışa aktarır', () async {
    await isar.writeTxn(() async {
      await isar.transactionEntitys.putAll([
        transaction(
          amountInMinor: 98765,
          transactionType: TransactionType.income,
          category: TransactionCategory.fatura,
          source: TransactionSource.ocrLlm,
          merchantName: 'Elektrik İdaresi',
          rawOcrText: 'Fatura no: 42',
          note: 'Temmuz faturası',
        ),
        transaction(
          amountInMinor: 50,
          category: TransactionCategory.ulasim,
          source: TransactionSource.ocrRegex,
          merchantName: 'Metro',
        ),
      ]);
    });

    final json = jsonDecode(await databaseExporter.exportJsonString()) as List;

    expect(json, hasLength(2));
    expect(
      json.first.keys,
      containsAll(<String>[
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
      ]),
    );
    expect(json.first['amountInMinor'], 98765);
    expect(json.first['transactionType'], 'income');
    expect(json.first['rawOcrText'], 'Fatura no: 42');
    expect(json.last['merchantName'], 'Metro');
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

  test(
    'CSV çıktısı BOM, Türkçe Excel ayıracı, başlıklar ve kaçış karakterlerini içerir',
    () async {
      await isar.writeTxn(
        () => isar.transactionEntitys.put(
          transaction(
            merchantName: '"Market, Şube"',
            note: 'İlk satır\nİkinci',
          ),
        ),
      );

      final csv = await databaseExporter.exportCsvString();

      expect(csv, startsWith('\uFEFFsep=;\r\nid;transactionType;amountInMinor'));
      expect(csv, contains('"""Market, Şube"""'));
      expect(csv, contains('"İlk satır\nİkinci"'));
    },
  );

  test('boş veritabanında CSV yalnızca başlık satırını üretir', () async {
    final csv = await databaseExporter.exportCsvString();

    expect(
      csv,
      '\uFEFFsep=;\r\nid;transactionType;amountInMinor;category;date;merchantName;source;rawOcrText;note;createdAt;updatedAt\r\n',
    );
  });

  test('CSV formül başlangıçlarını Excel için güvenli metne dönüştürür', () async {
    await isar.writeTxn(
      () => isar.transactionEntitys.putAll([
        transaction(
          merchantName: '=HYPERLINK("https://example.test")',
          rawOcrText: '+1+1',
          note: '-42',
        ),
        transaction(merchantName: '@komut'),
      ]),
    );

    final csv = await databaseExporter.exportCsvString();

    expect(csv, contains("'@komut"), reason: 'At işareti de metne çevrilir');
    expect(csv, contains("'-42"));
    expect(csv, contains("'+1+1"));
    expect(csv, contains("'="));
  });

  test('Türkçe Excel için virgül içeren metni ayrı bir sütunda tutar', () async {
    await isar.writeTxn(
      () => isar.transactionEntitys.put(
        transaction(merchantName: 'İstanbul, Kadıköy'),
      ),
    );

    final csv = await databaseExporter.exportCsvString();
    final lines = csv.split('\r\n');
    final headerColumns = lines[1].split(';');
    final dataColumns = lines[2].split(';');

    expect(csv, startsWith('\uFEFFsep=;\r\n'));
    expect(headerColumns, hasLength(11));
    expect(dataColumns, hasLength(11));
    expect(dataColumns[5], 'İstanbul, Kadıköy');
  });

  test('paylaşım hatasını uygulamaya özgü hata olarak bildirir', () async {
    final service = TransactionExportShareService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (_) async => throw StateError('Paylaşım uygulaması yok'),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await expectLater(
      service.exportAndShare(TransactionExportFormat.json),
      throwsA(
        isA<TransactionExportShareException>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
  });

  test('başarılı paylaşım sonrası geçici JSON dosyasını temizler', () async {
    String? sharedContent;
    late File sharedFile;
    final service = TransactionExportShareService(
      exportJson: () async => '[{"id":1}]',
      exportCsv: () async => '\uFEFFid\r\n1\r\n',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (file) async {
        sharedFile = file;
        sharedContent = await file.readAsString();
      },
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await service.exportAndShare(TransactionExportFormat.json);

    expect(sharedContent, '[{"id":1}]');
    expect(sharedFile.path, endsWith('.json'));
    expect(await sharedFile.exists(), isFalse);
  });

  test('CSV formatında doğru uzantılı geçici dosya oluşturur', () async {
    final service = TransactionExportShareService(
      exportJson: () async => '[]',
      exportCsv: () async => '\uFEFFid\r\n1\r\n',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (_) async {},
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    final file = await service.createExportFile(TransactionExportFormat.csv);

    expect(file.path, endsWith('.csv'));
    expect(await file.readAsString(), 'id\r\n1\r\n');
    await file.delete();
  });

  test('eski geçici export dosyalarını periyodik temizlikte siler', () async {
    final oldFile = File('${tempDirectory.path}/transactions_export_old.csv');
    final nonExportFile = File('${tempDirectory.path}/keep.txt');
    await oldFile.writeAsString('hassas veri');
    await nonExportFile.writeAsString('kalır');
    await oldFile.setLastModified(DateTime.utc(2026, 7, 28));

    final service = TransactionExportShareService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (_) async {},
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await service.cleanupOldExportFiles(tempDirectory);

    expect(await oldFile.exists(), isFalse);
    expect(await nonExportFile.exists(), isTrue);
  });

  test('paylaşım akışı başlamadan önce eski export dosyalarını temizler', () async {
    final oldFile = File('${tempDirectory.path}/transactions_export_old.json');
    await oldFile.writeAsString('eski yedek');
    final service = TransactionExportShareService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (_) async {},
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await service.exportAndShare(TransactionExportFormat.json);

    expect(await oldFile.exists(), isFalse);
  });

  test('geçici dosya silme hatası paylaşım sonucunu maskelemez', () async {
    final oldFile = File('${tempDirectory.path}/transactions_export_locked.json');
    await oldFile.writeAsString('silinemeyen eski dosya');
    final service = TransactionExportShareService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (_) async {},
      deleteFile: (_) async => throw FileSystemException('silinemedi'),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await service.exportAndShare(TransactionExportFormat.json);
  });

  test('geçici dosya silme hatası paylaşım hatasını maskelemez', () async {
    final service = TransactionExportShareService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      shareFile: (_) async => throw StateError('Paylaşım uygulaması yok'),
      deleteFile: (_) async => throw FileSystemException('silinemedi'),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await expectLater(
      service.exportAndShare(TransactionExportFormat.json),
      throwsA(isA<TransactionExportShareException>()),
    );
  });
}
