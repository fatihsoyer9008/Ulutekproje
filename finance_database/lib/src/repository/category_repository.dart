import 'package:isar/isar.dart';

import '../models/category_entity.dart';

class CategoryRepository {
  CategoryRepository(this._isar);

  final Isar _isar;

  Future<void> ensureDefaultCategories() async {
    final existingNames = (await _isar.categoryEntitys.where().findAll())
        .map((category) => _normalise(category.name))
        .toSet();
    final now = DateTime.now();
    final missing = defaultCategories
        .where((category) => !existingNames.contains(_normalise(category.name)))
        .map(
          (category) => CategoryEntity()
            ..name = category.name
            ..colorValue = category.colorValue
            ..iconCodePoint = category.iconCodePoint
            ..isDefault = true
            ..createdAt = now,
        )
        .toList();

    if (missing.isEmpty) return;
    await _isar.writeTxn(() => _isar.categoryEntitys.putAll(missing));
  }

  Future<List<CategoryEntity>> getAllCategories() async {
    final categories = await _isar.categoryEntitys.where().findAll();
    categories.sort(_compareCategories);
    return categories;
  }

  Stream<List<CategoryEntity>> watchAllCategories() async* {
    await ensureDefaultCategories();
    yield* _isar.categoryEntitys.where().watch(fireImmediately: true).map((
      categories,
    ) {
      categories.sort(_compareCategories);
      return categories;
    });
  }

  Future<Id> addCategory({
    required String name,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Kategori adı boş olamaz.');
    }

    final existing = await getAllCategories();
    if (existing.any(
      (category) => _normalise(category.name) == _normalise(trimmedName),
    )) {
      throw StateError('Bu kategori zaten mevcut.');
    }

    final category = CategoryEntity()
      ..name = trimmedName
      ..colorValue = colorValue
      ..iconCodePoint = iconCodePoint
      ..createdAt = DateTime.now();
    return _isar.writeTxn(() => _isar.categoryEntitys.put(category));
  }

  int _compareCategories(CategoryEntity left, CategoryEntity right) {
    if (left.isDefault != right.isDefault) return left.isDefault ? -1 : 1;
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  String _normalise(String value) => value.trim().toLowerCase();
}
