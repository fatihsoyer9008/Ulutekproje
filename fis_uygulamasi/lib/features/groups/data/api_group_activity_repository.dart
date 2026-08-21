import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/group_activity_models.dart';
import 'group_activity_repository.dart';
import 'group_api_failure.dart';

class ApiGroupActivityRepository implements GroupActivityRepository {
  const ApiGroupActivityRepository(this._apiClient, {this.currentUserId});

  final ApiClient _apiClient;
  final String? currentUserId;

  @override
  Future<GroupActivityPage> listActivity({
    int limit = 50,
    String? before,
  }) async {
    try {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/v1/activity',
        queryParameters: <String, Object?>{'limit': limit, 'before': ?before},
      );
      final body = Map<String, Object?>.from(response.data ?? const {});
      final rawItems = body['items'];
      if (rawItems is! List) {
        throw const FormatException('Activity items missing.');
      }

      return GroupActivityPage(
        items: rawItems
            .map(
              (item) => _entryFromJson(
                Map<String, Object?>.from(item as Map),
                currentUserId: currentUserId,
              ),
            )
            .toList(growable: false),
        nextCursor: _optionalString(body, 'next_cursor'),
      );
    } on DioException catch (error) {
      throw groupApiExceptionFromDio(
        error,
        fallbackMessage:
            'Hareketler yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.',
      );
    }
  }
}

GroupActivityEntry _entryFromJson(
  Map<String, Object?> json, {
  required String? currentUserId,
}) {
  final actor = _requiredMap(json, 'actor');
  final group = _requiredMap(json, 'group');
  final actorUserId = _requiredString(actor, 'user_id');
  final type = _activityType(_requiredString(json, 'type'));
  final expense = _optionalMap(json, 'expense_details');
  final settlement = _optionalMap(json, 'settlement_details');
  final member = _optionalMap(json, 'member_details');
  final impact = _optionalMap(json, 'impact');

  final subject = switch (type) {
    GroupActivityType.expenseAdded ||
    GroupActivityType.expenseUpdated ||
    GroupActivityType.expenseDeleted => _requiredString(expense, 'title'),
    GroupActivityType.settlementRecorded => 'settlement',
    GroupActivityType.memberJoined ||
    GroupActivityType.memberLeft ||
    GroupActivityType.invitationAccepted => _requiredString(
      member,
      'display_name',
    ),
    GroupActivityType.groupCreated => _requiredString(group, 'name'),
  };
  final currency = expense == null
      ? _optionalString(settlement, 'currency')
      : _optionalString(expense, 'currency');
  final (effect, amountInMinor) = _impact(impact);

  return GroupActivityEntry(
    id: _requiredString(json, 'id'),
    type: type,
    actorName: _requiredString(actor, 'display_name'),
    actorAvatarId: null,
    isCurrentUserActor: currentUserId != null && actorUserId == currentUserId,
    subject: subject,
    groupName: _requiredString(group, 'name'),
    occurredAt: DateTime.parse(_requiredString(json, 'created_at')),
    balanceEffect: effect,
    amountInMinor: amountInMinor,
    currency: currency,
  );
}

GroupActivityType _activityType(String value) => switch (value) {
  'expense_created' => GroupActivityType.expenseAdded,
  'expense_updated' => GroupActivityType.expenseUpdated,
  'expense_deleted' => GroupActivityType.expenseDeleted,
  'settlement_created' => GroupActivityType.settlementRecorded,
  'member_joined' => GroupActivityType.memberJoined,
  'member_left' => GroupActivityType.memberLeft,
  'invitation_accepted' => GroupActivityType.invitationAccepted,
  'group_created' => GroupActivityType.groupCreated,
  _ => throw FormatException('Unknown activity type: $value'),
};

(GroupActivityBalanceEffect, int) _impact(Map<String, Object?>? impact) {
  if (impact == null) return (GroupActivityBalanceEffect.neutral, 0);
  final amount = impact['amount_in_minor'];
  if (amount is! int || amount < 0) {
    throw const FormatException('Invalid activity impact amount.');
  }
  final effect = switch (_requiredString(impact, 'status')) {
    'you_are_owed' || 'you_get_back' => GroupActivityBalanceEffect.receivable,
    'you_owe' => GroupActivityBalanceEffect.payable,
    final value => throw FormatException('Unknown activity impact: $value'),
  };
  return (effect, amount);
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Missing activity field: $key');
  return Map<String, Object?>.from(value);
}

Map<String, Object?>? _optionalMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) throw FormatException('Invalid activity field: $key');
  return Map<String, Object?>.from(value);
}

String _requiredString(Map<String, Object?>? json, String key) {
  final value = json?[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing activity field: $key');
  }
  return value;
}

String? _optionalString(Map<String, Object?>? json, String key) {
  final value = json?[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid activity field: $key');
  return value;
}
