import 'package:app_main/features/sync/data/pending_task_sync_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RequestOptions request() => RequestOptions(path: '/api/v1/sync/push');

  test('format and ordinary 4xx errors are unrecoverable', () {
    expect(isUnrecoverableSyncError(const FormatException('bad payload')), isTrue);
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
}
