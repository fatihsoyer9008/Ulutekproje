import 'package:isar/isar.dart';

part 'category_entity.g.dart';

/// Kullanıcının işlem seçicilerinde görebileceği kategori tanımı.
@collection
class CategoryEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: false, caseSensitive: false)
  late String name;

  /// Flutter [Color] değerinin 32 bit ARGB karşılığı.
  late int colorValue;

  /// Uygulamanın desteklediği Material ikonunun code point değeri.
  late int iconCodePoint;

  bool isDefault = false;

  late DateTime createdAt;
}

class DefaultCategory {
  const DefaultCategory(this.name, this.colorValue, this.iconCodePoint);

  final String name;
  final int colorValue;
  final int iconCodePoint;
}

/// Material ikon code point'leri veri katmanını Flutter'a bağımlı kılmamak için
/// sabit değer olarak tutulur.
const defaultCategories = <DefaultCategory>[
  DefaultCategory('Market', 0xFF2E7D32, 0xE8CC),
  DefaultCategory('Ulaşım', 0xFF1565C0, 0xE530),
  DefaultCategory('Fatura', 0xFF6A1B9A, 0xE1F4),
  DefaultCategory('Eğlence', 0xFFEF6C00, 0xEA28),
  DefaultCategory('Sağlık', 0xFFC62828, 0xE3F3),
  DefaultCategory('Giyim', 0xFFAD1457, 0xF37F),
  DefaultCategory('Diğer', 0xFF546E7A, 0xE148),
  DefaultCategory('Maaş', 0xFF00838F, 0xE263),
];

List<CategoryEntity> createDefaultCategoryEntities() => [
  for (final category in defaultCategories)
    CategoryEntity()
      ..name = category.name
      ..colorValue = category.colorValue
      ..iconCodePoint = category.iconCodePoint
      ..isDefault = true
      ..createdAt = DateTime.fromMillisecondsSinceEpoch(0),
];
