import 'package:dio/dio.dart';

import '../domain/group_models.dart';

GroupApiException groupApiExceptionFromDio(
  DioException error, {
  required String fallbackMessage,
}) {
  final statusCode = error.response?.statusCode ?? 503;
  final retryAfterSeconds = statusCode == 429
      ? _retryAfterSeconds(error.response?.headers)
      : null;
  final structuredError = _structuredError(error.response?.data);
  if (structuredError != null && statusCode != 401) {
    final detail = structuredError.detail;
    final message = switch (statusCode) {
      403 => 'Bu işlem için grup yetkiniz bulunmamaktadır.',
      409
          when detail.code.contains('financial') ||
              detail.code.contains('lock') =>
        'Bu masraf finansal olarak kilitli olduğu için değiştirilemiyor.',
      409 =>
        'Masraf isteği daha önce farklı bilgilerle gönderildi. Lütfen yeniden deneyin.',
      429 when retryAfterSeconds != null =>
        'Çok fazla istek gönderildi. $retryAfterSeconds saniye sonra tekrar deneyin.',
      _ => detail.message,
    };
    return GroupApiException(
      statusCode: statusCode,
      error: GroupApiError(
        detail: GroupApiErrorDetail(
          code: detail.code,
          message: message,
          fieldErrors: detail.fieldErrors,
          unassignedReceiptLineItemIds: detail.unassignedReceiptLineItemIds,
          unassignedReceiptLineItemPositions:
              detail.unassignedReceiptLineItemPositions,
          retryAfterSeconds: retryAfterSeconds ?? detail.retryAfterSeconds,
        ),
      ),
    );
  }

  final (code, message) = switch (statusCode) {
    401 => (
      'unauthorized',
      'Oturum süreniz doldu. Lütfen yeniden giriş yapın.',
    ),
    403 => ('forbidden', 'Bu işlem için grup yetkiniz bulunmamaktadır.'),
    409 => (
      'conflict',
      'Masraf başka bir işlemle çakıştı. Lütfen bilgileri yenileyip tekrar deneyin.',
    ),
    422 => (
      'validation_error',
      'Masraf bilgileri doğrulanamadı. Lütfen payları ve toplam tutarı kontrol edin.',
    ),
    429 => (
      'rate_limited',
      retryAfterSeconds == null
          ? 'Çok fazla istek gönderildi. Lütfen biraz sonra tekrar deneyin.'
          : 'Çok fazla istek gönderildi. $retryAfterSeconds saniye sonra tekrar deneyin.',
    ),
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
      detail: GroupApiErrorDetail(
        code: code,
        message: message,
        retryAfterSeconds: retryAfterSeconds,
      ),
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
    final fieldErrors = <GroupApiFieldError>[];
    for (final item in detail) {
      if (item is! Map || item['msg'] is! String) continue;
      final location = item['loc'];
      final field = location is List
          ? location
                .whereType<Object>()
                .skipWhile((part) => part == 'body')
                .join('.')
          : 'request';
      fieldErrors.add(
        GroupApiFieldError(field: field, message: item['msg']! as String),
      );
    }
    if (fieldErrors.isNotEmpty) {
      return GroupApiError(
        detail: GroupApiErrorDetail(
          code: 'validation_error',
          message:
              'Gönderilen bilgiler geçersiz. Lütfen alanları kontrol edin.',
          fieldErrors: fieldErrors,
        ),
      );
    }
  }
  return null;
}

int? _retryAfterSeconds(Headers? headers) {
  final raw = headers?.value('retry-after')?.trim();
  return raw == null ? null : int.tryParse(raw);
}
