import 'dart:async';

import 'package:dio/dio.dart';

enum SyncErrorCategory {
  networkUnavailable('network_unavailable'),
  timeout('timeout'),
  invalidPayload('invalid_payload'),
  serverUnavailable('server_unavailable'),
  permanentFailure('permanent_failure');

  const SyncErrorCategory(this.code);

  final String code;
}

abstract interface class CategorizedSyncException implements Exception {
  SyncErrorCategory get category;
}

SyncErrorCategory categorizeSyncError(Object error) {
  if (error is CategorizedSyncException) return error.category;
  if (error is FormatException) return SyncErrorCategory.invalidPayload;
  if (error is TimeoutException) return SyncErrorCategory.timeout;

  if (error is DioException) {
    if (error.error is TimeoutException) return SyncErrorCategory.timeout;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return SyncErrorCategory.timeout;
      case DioExceptionType.connectionError:
        return SyncErrorCategory.networkUnavailable;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 408) return SyncErrorCategory.timeout;
        if (statusCode == 429 || (statusCode != null && statusCode >= 500)) {
          return SyncErrorCategory.serverUnavailable;
        }
        return SyncErrorCategory.permanentFailure;
      case DioExceptionType.unknown:
        return error.response == null
            ? SyncErrorCategory.networkUnavailable
            : SyncErrorCategory.serverUnavailable;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return SyncErrorCategory.permanentFailure;
    }
  }

  return SyncErrorCategory.permanentFailure;
}
