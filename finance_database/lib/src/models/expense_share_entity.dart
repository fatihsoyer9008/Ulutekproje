import 'package:isar/isar.dart';

part 'expense_share_entity.g.dart';

/// Pull ile gelen grup masrafı payının kullanıcı kapsamlı yerel kopyası.
///
/// Silinen paylar da [deletedAt] içeren tombstone olarak tutulur. Böylece eski
/// bir snapshot daha sonra işlense bile silme değişikliğini geri alamaz.
@collection
class ExpenseShareEntity {
  Id id = Isar.autoIncrement;

  /// `ownerKey|expenseId|userId` birleşiminden oluşan tekil yerel anahtar.
  @Index(unique: true, replace: false)
  late String recordKey;

  @Index()
  late String expenseId;

  late String userId;

  @Index()
  late String groupId;

  @Index()
  late String ownerKey;

  String? displayName;
  int? amountInMinor;
  String? status;
  DateTime? settledAt;

  /// ExpenseShare API sözleşmesinin kayıpsız JSON snapshot'ı.
  String? payloadJson;

  /// Son uygulanan pull değişikliğinin sunucu zamanı.
  late DateTime serverUpdatedAt;

  /// Null değilse kayıt aktif bir pay değil, kalıcı tombstone'dur.
  DateTime? deletedAt;
}
