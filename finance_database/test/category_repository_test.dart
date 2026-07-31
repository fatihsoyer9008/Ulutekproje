import 'dart:io';

import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory directory;
  late Isar isar;
  late CategoryRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'category_repository_test_',
    );
    isar = await Isar.open(
      [CategoryEntitySchema],
      directory: directory.path,
      name: 'category_repository_test',
    );
    repository = CategoryRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('varsayılan kategorileri yalnızca bir kez ekler', () async {
    await repository.ensureDefaultCategories();
    await repository.ensureDefaultCategories();

    final categories = await repository.getAllCategories();

    expect(categories, hasLength(defaultCategories.length));
    expect(categories.every((category) => category.isDefault), isTrue);
    expect(categories.map((category) => category.name), contains('Ulaşım'));
  });

  test('isim, renk ve ikonuyla özel kategori ekler', () async {
    await repository.ensureDefaultCategories();

    await repository.addCategory(
      name: '  Evcil Hayvan  ',
      colorValue: 0xFF00838F,
      iconCodePoint: 0xE91D,
    );

    final category = (await repository.getAllCategories()).singleWhere(
      (item) => item.name == 'Evcil Hayvan',
    );
    expect(category.colorValue, 0xFF00838F);
    expect(category.iconCodePoint, 0xE91D);
    expect(category.isDefault, isFalse);
  });

  test('aynı isim farklı harf büyüklüğüyle yeniden eklenemez', () async {
    await repository.ensureDefaultCategories();

    expect(
      () => repository.addCategory(
        name: 'market',
        colorValue: 0xFF000000,
        iconCodePoint: 0xE000,
      ),
      throwsStateError,
    );
  });
}
