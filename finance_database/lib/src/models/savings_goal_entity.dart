import 'package:isar/isar.dart';

part 'savings_goal_entity.g.dart';

@collection
class SavingsGoalEntity {
  Id id = Isar.autoIncrement;

  late String title;
  String? description;
  late int targetAmountInMinor;
  int currentAmountInMinor = 0;
  DateTime? targetDate;
  int? iconCodePoint;
  String? colorHex;
  late DateTime createdAt;

  @Index(caseSensitive: true)
  late String ownerKey;
}
