import 'dart:convert';
import 'dart:io';

import 'package:app_main/application/service/transaction_export_file_service.dart';
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
      [
        TransactionEntitySchema,
        ReceiptEntitySchema,
        ReceiptLineItemEntitySchema,
      ],
      directory: tempDirectory.path,
      name: 'export_service_test',
    );
    databaseExporter = TransactionExportService(isar, ownerKey: null);
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
    String? categoryName,
    TransactionSource source = TransactionSource.manual,
    String? merchantName,
    String? rawOcrText,
    String? note,
  }) {
    return TransactionEntity()
      ..amountInMinor = amountInMinor
      ..transactionType = transactionType
      ..category = category
      ..categoryName = categoryName
      ..date = DateTime.utc(2026, 7, 30, 10)
      ..merchantName = merchantName
      ..source = source
      ..rawOcrText = rawOcrText
      ..note = note
      ..createdAt = DateTime.utc(2026, 7, 30, 10)
      ..updatedAt = DateTime.utc(2026, 7, 30, 10);
  }

  Future<List<dynamic>> exportedTransactions() async {
    final json = jsonDecode(await databaseExporter.exportJsonString()) as Map;
    expect(json['schemaVersion'], 2);
    expect(DateTime.tryParse(json['exportedAt'] as String), isNotNull);
    return json['transactions'] as List<dynamic>;
  }

  test('kuruş değerini kayıpsız tam sayı olarak dışa aktarır', () async {
    await isar.writeTxn(() => isar.transactionEntitys.put(transaction()));

    final json = await exportedTransactions();

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

    final json = await exportedTransactions();

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

    final json = await exportedTransactions();

    expect(json.single['merchantName'], isNull);
    expect(json.single['rawOcrText'], isNull);
    expect(json.single['note'], isNull);
  });

  test('fiş ürünlerini JSON yedeğine dahil eder', () async {
    final entity = transaction(merchantName: 'Migros')
      ..receiptLineItems = [
        ReceiptLineItemEntity()
          ..transactionId = 0
          ..position = 0
          ..name = 'Süt'
          ..quantity = 2
          ..unitPriceInMinor = 1250
          ..totalAmountInMinor = 2500,
      ]
      ..receiptLineItemsLoaded = true;
    await TransactionRepository(isar).addTransaction(entity);

    final json = await exportedTransactions();
    final receiptItems = json.single['receiptItems'] as List;

    expect(receiptItems, hasLength(1));
    expect(receiptItems.single['name'], 'Süt');
    expect(receiptItems.single['totalAmountInMinor'], 2500);
  });

  test('özel kategori adını JSON export ve import boyunca korur', () async {
    await isar.writeTxn(
      () => isar.transactionEntitys.put(
        transaction(
          category: TransactionCategory.diger,
          categoryName: 'Evcil Hayvan',
          merchantName: 'Veteriner',
        ),
      ),
    );

    final exported = await databaseExporter.exportJsonString();
    final imported = TransactionJsonBackup.decode(exported).single;

    expect(imported.category, TransactionCategory.diger);
    expect(imported.categoryName, 'Evcil Hayvan');
  });

  test('Türkçe karakterleri UTF-8 JSON içinde bozulmadan korur', () async {
    const text = 'Şığ İÇÖÜ: çiğ köfte';
    await isar.writeTxn(
      () => isar.transactionEntitys.put(
        transaction(merchantName: text, note: text),
      ),
    );

    final json = await exportedTransactions();

    expect(json.single['merchantName'], text);
    expect(json.single['note'], text);
  });

  test('boş veritabanında geçerli boş JSON dizisi üretir', () async {
    expect(await exportedTransactions(), isEmpty);
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

      expect(
        csv,
        startsWith('\uFEFFsep=;\r\nid;transactionType;amountInMinor'),
      );
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

  test('dışa aktarılan CSV yeniden içe aktarılabilir', () async {
    await isar.writeTxn(
      () => isar.transactionEntitys.put(
        transaction(
          amountInMinor: 4321,
          merchantName: 'Market; Kadıköy',
          note: 'Birinci satır\nİkinci satır',
        ),
      ),
    );

    final csv = await databaseExporter.exportCsvString();
    final imported = TransactionCsvBackup.decode(csv);

    expect(imported, hasLength(1));
    expect(imported.single.amountInMinor, 4321);
    expect(imported.single.merchantName, 'Market; Kadıköy');
    expect(imported.single.note, 'Birinci satır\nİkinci satır');
  });

  test(
    'CSV formül başlangıçlarını Excel için güvenli metne dönüştürür',
    () async {
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
    },
  );

  test(
    'Türkçe Excel için virgül içeren metni ayrı bir sütunda tutar',
    () async {
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
    },
  );

  test('kayıt hatasını uygulamaya özgü hata olarak bildirir', () async {
    final service = TransactionExportFileService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      saveFile: (_, _, _) async => throw StateError('Documents kullanılamıyor'),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await expectLater(
      service.exportAndSave(TransactionExportFormat.json),
      throwsA(
        isA<TransactionExportFileException>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
  });

  test('başarılı kayıt sonrası geçici JSON dosyasını temizler', () async {
    String? savedContent;
    late File savedFile;
    final service = TransactionExportFileService(
      exportJson: () async => '[{"id":1}]',
      exportCsv: () async => '\uFEFFid\r\n1\r\n',
      temporaryDirectory: () async => tempDirectory,
      saveFile: (file, fileName, mimeType) async {
        savedFile = file;
        savedContent = await file.readAsString();
        expect(fileName, endsWith('.json'));
        expect(mimeType, 'application/json');
        return TransactionExportSaveResult.documents(fileName);
      },
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    final result = await service.exportAndSave(TransactionExportFormat.json);

    expect(result.displayValue, endsWith('.json'));
    expect(result.destination, TransactionExportSaveDestination.documents);
    expect(savedContent, '[{"id":1}]');
    expect(savedFile.path, endsWith('.json'));
    expect(await savedFile.exists(), isFalse);
  });

  test('CSV formatında doğru uzantılı geçici dosya oluşturur', () async {
    final service = TransactionExportFileService(
      exportJson: () async => '[]',
      exportCsv: () async => '\uFEFFid\r\n1\r\n',
      temporaryDirectory: () async => tempDirectory,
      saveFile: (_, fileName, _) async =>
          TransactionExportSaveResult.documents(fileName),
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

    final service = TransactionExportFileService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      saveFile: (_, fileName, _) async =>
          TransactionExportSaveResult.documents(fileName),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await service.cleanupOldExportFiles(tempDirectory);

    expect(await oldFile.exists(), isFalse);
    expect(await nonExportFile.exists(), isTrue);
  });

  test(
    'kayıt akışı başlamadan önce eski export dosyalarını temizler',
    () async {
      final oldFile = File(
        '${tempDirectory.path}/transactions_export_old.json',
      );
      await oldFile.writeAsString('eski yedek');
      final service = TransactionExportFileService(
        exportJson: () async => '[]',
        exportCsv: () async => '',
        temporaryDirectory: () async => tempDirectory,
        saveFile: (_, fileName, _) async =>
            TransactionExportSaveResult.documents(fileName),
        now: () => DateTime.utc(2026, 7, 30, 10),
      );

      await service.exportAndSave(TransactionExportFormat.json);

      expect(await oldFile.exists(), isFalse);
    },
  );

  test('geçici dosya silme hatası kayıt sonucunu maskelemez', () async {
    final oldFile = File(
      '${tempDirectory.path}/transactions_export_locked.json',
    );
    await oldFile.writeAsString('silinemeyen eski dosya');
    final service = TransactionExportFileService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      saveFile: (_, fileName, _) async =>
          TransactionExportSaveResult.documents(fileName),
      deleteFile: (_) async => throw FileSystemException('silinemedi'),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await service.exportAndSave(TransactionExportFormat.json);
  });

  test('geçici dosya silme hatası kayıt hatasını maskelemez', () async {
    final service = TransactionExportFileService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      saveFile: (_, _, _) async => throw StateError('Documents kullanılamıyor'),
      deleteFile: (_) async => throw FileSystemException('silinemedi'),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await expectLater(
      service.exportAndSave(TransactionExportFormat.json),
      throwsA(isA<TransactionExportFileException>()),
    );
  });

  test('directory listing failure does not block saving', () async {
    var saved = false;
    final service = TransactionExportFileService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      listDirectory: (_) =>
          Stream<FileSystemEntity>.error(FileSystemException('listing failed')),
      saveFile: (_, fileName, _) async {
        saved = true;
        return TransactionExportSaveResult.documents(fileName);
      },
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await service.exportAndSave(TransactionExportFormat.json);

    expect(saved, isTrue);
  });

  group('platform export fallback', () {
    late File exportFile;
    late List<String> calls;

    setUp(() async {
      exportFile = File('${tempDirectory.path}/platform_export.json');
      await exportFile.writeAsString('[]');
      calls = <String>[];
    });

    Future<String> androidSaver(File _, String fileName, String _) async {
      calls.add('android');
      return fileName;
    }

    Future<String> iosShareFallback(File _, String fileName, String _) async {
      calls.add('ios');
      return fileName;
    }

    Future<String> saveDialogFallback(File _, String fileName, String _) async {
      calls.add('dialog');
      return fileName;
    }

    Future<TransactionExportSaveResult> saveFor(
      TransactionExportPlatform platform,
    ) => saveTransactionExportFile(
      exportFile,
      'transactions.json',
      'application/json',
      platform: platform,
      androidSaver: androidSaver,
      iosShareFallback: iosShareFallback,
      saveDialogFallback: saveDialogFallback,
    );

    test('Android MediaStore kaydedicisini korur', () async {
      final result = await saveFor(TransactionExportPlatform.android);

      expect(result.displayValue, 'transactions.json');
      expect(result.destination, TransactionExportSaveDestination.documents);
      expect(calls, ['android']);
    });

    test('iOS paylaşım fallback yolunu kullanır', () async {
      final result = await saveFor(TransactionExportPlatform.ios);

      expect(result.displayValue, 'transactions.json');
      expect(result.destination, TransactionExportSaveDestination.shareSheet);
      expect(calls, ['ios']);
    });

    test('diğer platformlarda kaydetme diyaloğunu kullanır', () async {
      final result = await saveFor(TransactionExportPlatform.other);

      expect(result.displayValue, 'transactions.json');
      expect(
        result.destination,
        TransactionExportSaveDestination.selectedLocation,
      );
      expect(calls, ['dialog']);
    });
  });

  test('kullanıcı iptalini kayıt hatasına dönüştürmez', () async {
    final service = TransactionExportFileService(
      exportJson: () async => '[]',
      exportCsv: () async => '',
      temporaryDirectory: () async => tempDirectory,
      saveFile: (_, _, _) async =>
          throw const TransactionExportCancelledException(),
      now: () => DateTime.utc(2026, 7, 30, 10),
    );

    await expectLater(
      service.exportAndSave(TransactionExportFormat.json),
      throwsA(isA<TransactionExportCancelledException>()),
    );
  });
}
