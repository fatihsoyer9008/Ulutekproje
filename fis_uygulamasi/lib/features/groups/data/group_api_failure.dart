import 'package:dio/dio.dart';

import '../domain/group_models.dart';

GroupApiException groupApiExceptionFromDio(
  DioException error, {
  required String fallbackMessage,
}) {
  final statusCode = error.response?.statusCode ?? 503;
  final structuredError = _structuredError(error.response?.data);
  if (structuredError != null && statusCode != 401) {
    return GroupApiException(statusCode: statusCode, error: structuredError);
  }

  final (code, message) = switch (statusCode) {
    401 => (
      'unauthorized',
      'Oturum süreniz doldu. Lütfen yeniden giriş yapın.',
    ),
    403 => ('forbidden', 'Bu işlem için yetkiniz bulunmuyor.'),
    404 => ('not_found', 'İstenen grup kaydı bulunamadı.'),
    408 || 504 => ('timeout', 'Sunucu yanıt vermedi. Lütfen tekrar deneyin.'),
    >= 500 => (
      'service_unavailable',
      'Grup servisine şu anda ulaşılamıyor. Lütfen tekrar deneyin.',
    ),
    _ => ('request_failed', fallbackMessage),
  };

  return GroupApiException(
    statusCode: statusCode,
    error: GroupApiError(
      detail: GroupApiErrorDetail(code: code, message: message),
    ),
  );
}

String groupUserMessage(Object error, {required String fallbackMessage}) {
  if (error is GroupApiException) return error.error.detail.message;
  if (error is FormatException || error is TypeError) {
    return 'Sunucudan beklenmeyen bir yanıt alındı. Lütfen tekrar deneyin.';
  }
  return fallbackMessage;
}

GroupApiError? _structuredError(Object? body) {
  if (body is! Map) return null;
  final detail = body['detail'];
  if (detail is Map) {
    final normalized = Map<String, Object?>.from(detail);
    if (normalized['code'] is String && normalized['message'] is String) {
      return GroupApiError.fromJson(<String, Object?>{'detail': normalized});
    }
  }
  if (detail is List && detail.isNotEmpty) {
    final first = detail.first;
    if (first is Map && first['msg'] is String) {
      return GroupApiError(
        detail: GroupApiErrorDetail(
          code: 'validation_error',
          message:
              'Gönderilen bilgiler geçersiz. Lütfen alanları kontrol edin.',
        ),
      );
    }
  }
  return null;
}
