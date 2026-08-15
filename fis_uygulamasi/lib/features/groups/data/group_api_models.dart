import '../domain/group_models.dart';

/// API katmanındaki response envelope'larını domain modellerinden ayırır.
///
/// Böylece endpoint sözleşmesindeki bir envelope değişikliği presentation
/// katmanına sızmaz; eksik veya bozuk cevaplar da tek noktada reddedilir.
final class GroupsApiResponse {
  const GroupsApiResponse(this.groups);

  factory GroupsApiResponse.fromJson(Map<String, Object?> json) {
    return GroupsApiResponse(
      _objectList(
        json['groups'],
        'groups',
      ).map(GroupApiModel.fromJson).toList(growable: false),
    );
  }

  final List<GroupApiModel> groups;

  GroupsResponse toDomain() => GroupsResponse(
    groups: groups.map((group) => group.toDomain()).toList(growable: false),
  );
}

final class GroupEnvelopeApiResponse {
  const GroupEnvelopeApiResponse(this.group);

  factory GroupEnvelopeApiResponse.fromJson(Map<String, Object?> json) =>
      GroupEnvelopeApiResponse(
        GroupDetailApiModel.fromJson(_objectMap(json['group'], 'group')),
      );

  final GroupDetailApiModel group;

  GroupDetail toDomain() => group.toDomain();
}

final class GroupMemberEnvelopeApiResponse {
  const GroupMemberEnvelopeApiResponse(this.member);

  factory GroupMemberEnvelopeApiResponse.fromJson(Map<String, Object?> json) =>
      GroupMemberEnvelopeApiResponse(
        GroupMemberApiModel.fromJson(_objectMap(json['member'], 'member')),
      );

  final GroupMemberApiModel member;

  GroupMember toDomain() => member.toDomain();
}

final class GroupMembersApiResponse {
  const GroupMembersApiResponse(this.members);

  factory GroupMembersApiResponse.fromJson(Map<String, Object?> json) =>
      GroupMembersApiResponse(
        _objectList(
          json['members'],
          'members',
        ).map(GroupMemberApiModel.fromJson).toList(growable: false),
      );

  final List<GroupMemberApiModel> members;

  List<GroupMember> toDomain() =>
      members.map((member) => member.toDomain()).toList(growable: false);
}

final class GroupExpensesApiResponse {
  const GroupExpensesApiResponse(this.expenses);

  factory GroupExpensesApiResponse.fromJson(Map<String, Object?> json) =>
      GroupExpensesApiResponse(
        _objectList(
          json['expenses'],
          'expenses',
        ).map(GroupExpenseApiModel.fromJson).toList(growable: false),
      );

  final List<GroupExpenseApiModel> expenses;

  List<GroupExpense> toDomain() =>
      expenses.map((expense) => expense.toDomain()).toList(growable: false);
}

final class GroupExpenseEnvelopeApiResponse {
  const GroupExpenseEnvelopeApiResponse(this.expense);

  factory GroupExpenseEnvelopeApiResponse.fromJson(Map<String, Object?> json) =>
      GroupExpenseEnvelopeApiResponse(
        GroupExpenseApiModel.fromJson(_objectMap(json['expense'], 'expense')),
      );

  final GroupExpenseApiModel expense;

  GroupExpense toDomain() => expense.toDomain();
}

final class DebtSummaryApiResponse {
  const DebtSummaryApiResponse._(this._json);

  factory DebtSummaryApiResponse.fromJson(Map<String, Object?> json) {
    _objectList(json['balances'], 'balances');
    _objectList(json['suggested_transfers'], 'suggested_transfers');
    return DebtSummaryApiResponse._(json);
  }

  final Map<String, Object?> _json;

  DebtSummary toDomain() => DebtSummary.fromJson(_json);
}

final class SettlementsApiResponse {
  const SettlementsApiResponse(this.settlements);

  factory SettlementsApiResponse.fromJson(Map<String, Object?> json) =>
      SettlementsApiResponse(
        _objectList(
          json['settlements'],
          'settlements',
        ).map(SettlementApiModel.fromJson).toList(growable: false),
      );

  final List<SettlementApiModel> settlements;

  List<Settlement> toDomain() => settlements
      .map((settlement) => settlement.toDomain())
      .toList(growable: false);
}

final class SettlementEnvelopeApiResponse {
  const SettlementEnvelopeApiResponse(this.settlement);

  factory SettlementEnvelopeApiResponse.fromJson(Map<String, Object?> json) =>
      SettlementEnvelopeApiResponse(
        SettlementApiModel.fromJson(
          _objectMap(json['settlement'], 'settlement'),
        ),
      );

  final SettlementApiModel settlement;

  Settlement toDomain() => settlement.toDomain();
}

final class GroupApiModel {
  const GroupApiModel._(this._json);

  factory GroupApiModel.fromJson(Map<String, Object?> json) {
    _requiredString(json, 'id');
    _requiredString(json, 'name');
    return GroupApiModel._(json);
  }

  final Map<String, Object?> _json;

  Group toDomain() => Group.fromJson(_json);
}

final class GroupDetailApiModel {
  const GroupDetailApiModel._(this._json);

  factory GroupDetailApiModel.fromJson(Map<String, Object?> json) {
    _requiredString(json, 'id');
    _objectList(json['members'], 'members');
    return GroupDetailApiModel._(json);
  }

  final Map<String, Object?> _json;

  GroupDetail toDomain() => GroupDetail.fromJson(_json);
}

final class GroupMemberApiModel {
  const GroupMemberApiModel._(this._json);

  factory GroupMemberApiModel.fromJson(Map<String, Object?> json) {
    _requiredString(json, 'user_id');
    if (json['display_name'] == null) _requiredString(json, 'name');
    return GroupMemberApiModel._(json);
  }

  final Map<String, Object?> _json;

  GroupMember toDomain() => GroupMember.fromJson(_json);
}

final class GroupExpenseApiModel {
  const GroupExpenseApiModel._(this._json);

  factory GroupExpenseApiModel.fromJson(Map<String, Object?> json) {
    _requiredString(json, 'id');
    _objectList(json['shares'], 'shares');
    _objectList(json['line_item_assignments'], 'line_item_assignments');
    _objectList(json['extra_amounts'], 'extra_amounts');
    return GroupExpenseApiModel._(json);
  }

  final Map<String, Object?> _json;

  GroupExpense toDomain() => GroupExpense.fromJson(_json);
}

final class SettlementApiModel {
  const SettlementApiModel._(this._json);

  factory SettlementApiModel.fromJson(Map<String, Object?> json) {
    _requiredString(json, 'id');
    _requiredString(json, 'group_id');
    return SettlementApiModel._(json);
  }

  final Map<String, Object?> _json;

  Settlement toDomain() => Settlement.fromJson(_json);
}

Map<String, Object?> _objectMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('API cevabında "$field" nesnesi eksik.');
  }
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _objectList(Object? value, String field) {
  if (value is! List) {
    throw FormatException('API cevabında "$field" listesi eksik.');
  }
  return [for (final item in value) _objectMap(item, '$field[]')];
}

String _requiredString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    throw FormatException('API cevabında "$field" alanı geçersiz.');
  }
  return value;
}
