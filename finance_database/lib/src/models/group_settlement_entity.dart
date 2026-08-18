import 'package:isar/isar.dart';

part 'group_settlement_entity.g.dart';

/// Pull ile gelen immutable settlement kaydının kullanıcı kapsamlı kopyası.
@collection
class GroupSettlementEntity {
  Id id = Isar.autoIncrement;

  /// `ownerKey|settlementId` birleşiminden oluşan tekil yerel anahtar.
  @Index(unique: true, replace: false)
  late String recordKey;

  @Index()
  late String settlementId;

  @Index()
  late String groupId;

  @Index()
  late String ownerKey;

  late String fromUserId;
  late String toUserId;
  late int amountInMinor;
  late String currency;
  late DateTime settledAt;
  String? note;
  late DateTime createdAt;

  /// Settlement API sözleşmesinin kayıpsız JSON snapshot'ı.
  late String payloadJson;

  /// Son uygulanan pull değişikliğinin sunucu zamanı.
  late DateTime serverUpdatedAt;
}
