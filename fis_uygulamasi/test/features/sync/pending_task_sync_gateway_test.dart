import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/core/network/api_client.dart';
import 'package:app_main/core/storage/installation_id_provider.dart';
import 'package:app_main/core/storage/secure_token_storage.dart';
import 'package:app_main/features/sync/data/pending_task_sync_gateway.dart';
import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RequestOptions request() => RequestOptions(path: '/api/v1/sync/push');

  test('format and ordinary 4xx errors are unrecoverable', () {
    expect(
      isUnrecoverableSyncError(const FormatException('bad payload')),
      isTrue,
    );
    expect(
      isUnrecoverableSyncError(
        DioException(
          requestOptions: request(),
          response: Response<void>(requestOptions: request(), statusCode: 422),
        ),
      ),
      isTrue,
    );
  });

  test('timeouts, rate limits, server and network errors are recoverable', () {
    for (final status in [408, 429, 500, 503]) {
      expect(
        isUnrecoverableSyncError(
          DioException(
            requestOptions: request(),
            response: Response<void>(
              requestOptions: request(),
              statusCode: status,
            ),
          ),
        ),
        isFalse,
      );
    }
    expect(
      isUnrecoverableSyncError(
        DioException(
          requestOptions: request(),
          type: DioExceptionType.connectionError,
        ),
      ),
      isFalse,
    );
  });

  for (final status in ['created', 'updated', 'unchanged', 'deleted']) {
    test('HTTP 200 $status sonucunu başarılı kabul eder', () async {
      final fixture = _GatewayFixture(status: status);
      addTearDown(fixture.close);

      await fixture.gateway.send(fixture.task);

      expect(fixture.requests, 1);
    });
  }

  test('HTTP 200 conflict sonucunu exception olarak döndürür', () async {
    final fixture = _GatewayFixture(status: 'conflict');
    addTearDown(fixture.close);

    await expectLater(
      fixture.gateway.send(fixture.task),
      throwsA(isA<SyncConflictException>()),
    );
  });

  test('boş, bilinmeyen veya eşleşmeyen HTTP 200 sonucunu reddeder', () async {
    for (final body in [
      <String, dynamic>{'results': <Object>[]},
      <String, dynamic>{
        'results': [
          {'operation_id': 'operation-1', 'status': 'mystery'},
        ],
      },
      <String, dynamic>{
        'results': [
          {'operation_id': 'another-operation', 'status': 'created'},
        ],
      },
    ]) {
      final fixture = _GatewayFixture(body: body);
      addTearDown(fixture.close);
      await expectLater(
        fixture.gateway.send(fixture.task),
        throwsA(isA<FormatException>()),
      );
    }
  });
}

class _GatewayFixture {
  _GatewayFixture({String? status, Map<String, dynamic>? body}) {
    final responseBody =
        body ??
        {
          'results': [
            {'operation_id': 'operation-1', 'status': status},
          ],
        };
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _FakeAdapter((options) async {
        requests += 1;
        return ResponseBody.fromString(
          jsonEncode(responseBody),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
    apiClient = ApiClient(
      baseUrl: 'https://example.test',
      tokenStorage: _MemoryTokenStorage(),
      dio: dio,
      refreshDio: Dio(BaseOptions(baseUrl: 'https://example.test')),
    );
    gateway = DioPendingTaskSyncGateway(
      apiClient: apiClient,
      installationIdProvider: _InstallationIdProvider(),
    );
  }

  late final ApiClient apiClient;
  late final DioPendingTaskSyncGateway gateway;
  int requests = 0;

  final task = OfflineTask()
    ..id = 1
    ..clientTaskId = 'operation-1'
    ..type = OfflineTaskType.updateTransaction
    ..payloadJson = jsonEncode({
      'operation_id': 'operation-1',
      'action': 'upsert',
      'client_record_id': '25d31160-0bb7-4faa-b79b-1af515ac6400',
      'client_updated_at': '2026-08-05T08:00:00Z',
      'transaction': <String, dynamic>{},
    });

  void close() => apiClient.close();
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

class _InstallationIdProvider implements InstallationIdProvider {
  @override
  Future<String> getInstallationId() async => 'installation-123456789';
}

class _MemoryTokenStorage implements TokenStorage {
  @override
  Future<void> deleteRefreshToken() async {}

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String token) async {}
}
