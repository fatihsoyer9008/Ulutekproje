import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/auth/presentation/controllers/auth_session_controller.dart';
import 'package:app_main/features/groups/data/api_group_repository.dart';
import 'package:app_main/features/groups/data/group_providers.dart';
import 'package:app_main/features/groups/domain/group_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/group_fixtures.dart';

void main() {
  test('production provider Dio tabanlı repository üretir', () {
    final client = _client((_) => _jsonResponse(const {'groups': []}));
    addTearDown(client.close);
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    expect(container.read(groupRepositoryProvider), isA<ApiGroupRepository>());
    expect(
      container.read(groupRepositoryProvider).capabilities.supportsInvitations,
      isTrue,
    );
  });

  test('production repository davet oluşturma endpointine POST atar', () async {
    late RequestOptions captured;
    final repository = ApiGroupRepository(
      _client((options) {
        captured = options;
        return _jsonResponse(const {
          'status': 'request_received',
        }, statusCode: 202);
      }),
    );

    await repository.createInvitation(
      groupId: twoMemberGroupId,
      email: 'invitee@example.com',
      role: GroupRole.admin,
    );

    expect(repository.capabilities.supportsInvitations, isTrue);
    expect(captured.method, 'POST');
    expect(captured.path, '/api/v1/groups/$twoMemberGroupId/invitations');
    expect(captured.data, {'email': 'invitee@example.com', 'role': 'admin'});
  });

  test('production repository davet kabul endpointine POST atar', () async {
    late RequestOptions captured;
    final member = twoMemberGroup.members.first;
    final repository = ApiGroupRepository(
      _client((options) {
        captured = options;
        return _jsonResponse({'member': member.toJson()}, statusCode: 201);
      }),
    );

    final accepted = await repository.acceptInvitation('opaque-token');

    expect(captured.method, 'POST');
    expect(captured.path, '/api/v1/group-invitations/opaque-token/accept');
    expect(accepted.groupId, twoMemberGroupId);
    expect(accepted.userId, member.userId);
  });

  test(
    'grup listesi API response modelinden domain modeline map edilir',
    () async {
      late RequestOptions captured;
      final repository = ApiGroupRepository(
        _client((options) {
          captured = options;
          return _jsonResponse({
            'groups': [twoMemberGroup.toJson()..remove('members')],
          });
        }),
      );

      final response = await repository.listGroups(includeArchived: true);

      expect(captured.path, '/api/v1/groups');
      expect(captured.queryParameters['include_archived'], isTrue);
      expect(response.groups, hasLength(1));
      expect(response.groups.single.id, twoMemberGroup.id);
      expect(response.groups.single.name, twoMemberGroup.name);
    },
  );

  test(
    'grup detay envelope response modeli domain detayına map edilir',
    () async {
      final repository = ApiGroupRepository(
        _client((_) => _jsonResponse({'group': twoMemberGroup.toJson()})),
      );

      final group = await repository.getGroup(twoMemberGroupId);

      expect(group, isA<GroupDetail>());
      expect(group.members, hasLength(2));
      expect(group.members.first.userId, currentUserId);
    },
  );

  test('yapılandırılmış API hatası kullanıcı mesajına map edilir', () async {
    final repository = ApiGroupRepository(
      _client(
        (_) => _jsonResponse({
          'detail': {
            'code': 'group_forbidden',
            'message': 'Bu grup için yetkiniz yok.',
          },
        }, statusCode: 403),
      ),
    );

    await expectLater(
      repository.getGroup(twoMemberGroupId),
      throwsA(
        isA<GroupApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having(
              (error) => error.error.detail.message,
              'message',
              'Bu grup için yetkiniz yok.',
            ),
      ),
    );
  });
}

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
