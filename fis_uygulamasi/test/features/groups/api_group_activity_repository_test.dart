import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/groups/data/api_group_activity_repository.dart';
import 'package:app_main/features/groups/data/group_activity_repository.dart';
import 'package:app_main/features/groups/domain/group_activity_models.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity endpointini domain modeline map eder', () async {
    late RequestOptions captured;
    final client = _client((options) {
      captured = options;
      return _jsonResponse({
        'items': [_expenseActivityJson(), _memberActivityJson()],
        'next_cursor': null,
      });
    });
    addTearDown(client.close);
    final repository = ApiGroupActivityRepository(
      client,
      currentUserId: _currentUserId,
    );

    final page = await repository.listActivity(limit: 20);

    expect(captured.path, '/api/v1/activity');
    expect(captured.queryParameters, {'limit': 20});
    expect(page.nextCursor, isNull);
    expect(page.items, hasLength(2));
    expect(page.items.first.type, GroupActivityType.expenseAdded);
    expect(page.items.first.isCurrentUserActor, isTrue);
    expect(page.items.first.subject, 'Elektrik');
    expect(
      page.items.first.balanceEffect,
      GroupActivityBalanceEffect.receivable,
    );
    expect(page.items.first.amountInMinor, 15350);
    expect(page.items.first.currency, 'TRY');
    expect(page.items.last.type, GroupActivityType.memberJoined);
    expect(page.items.last.balanceEffect, GroupActivityBalanceEffect.neutral);
  });

  test('cursor sayfalarını tekrarsız biçimde birleştirir', () async {
    final requestedCursors = <Object?>[];
    final client = _client((options) {
      requestedCursors.add(options.queryParameters['before']);
      if (options.queryParameters['before'] == null) {
        return _jsonResponse({
          'items': [_expenseActivityJson()],
          'next_cursor': 'cursor-2',
        });
      }
      return _jsonResponse({
        'items': [_expenseActivityJson(), _memberActivityJson()],
        'next_cursor': null,
      });
    });
    addTearDown(client.close);

    final result = await loadAllGroupActivity(
      ApiGroupActivityRepository(client, currentUserId: _currentUserId),
    );

    expect(requestedCursors, [null, 'cursor-2']);
    expect(result, hasLength(2));
    expect(result.first.occurredAt.isAfter(result.last.occurredAt), isTrue);
  });

  test('tekrarlanan cursor sonsuz isteğe dönüşmez', () async {
    final repository = _RepeatedCursorRepository();

    await expectLater(
      loadAllGroupActivity(repository),
      throwsA(isA<FormatException>()),
    );
    expect(repository.calls, 2);
  });

  test('API teknik hata mesajını kullanıcıya taşımaz', () async {
    final client = _client(
      (_) => _jsonResponse({
        'detail': 'Internal DB table=activity_log host=private-db',
      }, statusCode: 500),
    );
    addTearDown(client.close);
    final repository = ApiGroupActivityRepository(client);

    await expectLater(
      repository.listActivity(),
      throwsA(
        isA<GroupApiException>().having(
          (error) => error.error.detail.message,
          'message',
          'Grup servisine şu anda ulaşılamıyor. Lütfen tekrar deneyin.',
        ),
      ),
    );
  });
}

const _currentUserId = '6f1c2e10-6b1b-4b1b-9f1a-1a2b3c4d5e6f';

Map<String, Object?> _expenseActivityJson() => {
  'id': '9c5f8154-af5f-4f5f-b05e-5e6f70819203',
  'type': 'expense_created',
  'actor': {'user_id': _currentUserId, 'display_name': 'Sen'},
  'group': {
    'id': '550e8400-e29b-41d4-a716-446655440000',
    'name': 'Bursa',
    'is_direct': false,
  },
  'expense_details': {
    'expense_id': 'ad6e9265-b06f-4f6f-b16f-6f708192a3b4',
    'title': 'Elektrik',
    'total_amount_in_minor': 30700,
    'currency': 'TRY',
  },
  'impact': {'status': 'you_are_owed', 'amount_in_minor': 15350},
  'created_at': '2026-08-18T15:22:00Z',
};

Map<String, Object?> _memberActivityJson() => {
  'id': 'ae7fa376-c17f-4f7f-c27f-7f8192a3b4c5',
  'type': 'member_joined',
  'actor': {
    'user_id': '7a3e6f32-8d3d-4d3d-9f3c-3c4d5e6f7081',
    'display_name': 'Ege B.',
  },
  'group': {
    'id': '550e8400-e29b-41d4-a716-446655440000',
    'name': 'Bursa',
    'is_direct': false,
  },
  'member_details': {
    'user_id': '8b4f7043-9e4e-4e4e-af4d-4d5e6f708192',
    'display_name': 'Ayşe',
  },
  'created_at': '2026-08-15T13:55:00Z',
};

ApiClient _client(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = _Adapter(handler);
  return ApiClient(
    baseUrl: 'https://example.test',
    tokenStorage: _TokenStorage(),
    dio: dio,
    refreshDio: Dio(BaseOptions(baseUrl: 'https://example.test')),
  );
}

ResponseBody _jsonResponse(Map<String, Object?> body, {int statusCode = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}

class _TokenStorage implements TokenStorage {
  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String token) async {}
}

class _RepeatedCursorRepository implements GroupActivityRepository {
  int calls = 0;

  @override
  Future<GroupActivityPage> listActivity({
    int limit = 50,
    String? before,
  }) async {
    calls++;
    return const GroupActivityPage(items: [], nextCursor: 'same-cursor');
  }
}
