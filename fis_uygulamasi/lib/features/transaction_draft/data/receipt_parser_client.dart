import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../model/transaction_draft.dart';

class ReceiptParseResult {
  const ReceiptParseResult({
    required this.draft,
    required this.normalizedOcrText,
    required this.confidenceScore,
    required this.isParseSuccessful,
    this.usedLocalFallback = false,
  });

  final TransactionDraft draft;
  final String normalizedOcrText;
  final double confidenceScore;
  final bool isParseSuccessful;
  final bool usedLocalFallback;

  factory ReceiptParseResult.fromJson(Map<String, dynamic> json) {
    final normalizedOcrText = json['normalized_ocr_text'];
    final confidence = json['confidence_score'];
    final successful = json['is_parse_successful'];
    if (normalizedOcrText is! String ||
        normalizedOcrText.trim().isEmpty ||
        confidence is! num ||
        confidence < 0 ||
        confidence > 1 ||
        successful is! bool) {
      throw const ReceiptParserException(
        'Fiş servisi beklenen formatta yanıt vermedi.',
        kind: ReceiptParserFailureKind.invalidResponse,
      );
    }

    return ReceiptParseResult(
      draft: TransactionDraft.fromJson(json),
      normalizedOcrText: normalizedOcrText,
      confidenceScore: confidence.toDouble(),
      isParseSuccessful: successful,
    );
  }
}

enum ReceiptParserFailureKind {
  emptyOcr,
  noInternet,
  dns,
  timeout,
  geminiUnavailable,
  serviceConfiguration,
  serviceUnavailable,
  invalidResponse,
  cancelled,
  unknown,
}

class ReceiptParserException implements Exception {
  const ReceiptParserException(
    this.message, {
    this.kind = ReceiptParserFailureKind.unknown,
  });

  final String message;
  final ReceiptParserFailureKind kind;

  bool get isCancelled => kind == ReceiptParserFailureKind.cancelled;

  bool get canRetry =>
      kind != ReceiptParserFailureKind.emptyOcr && !isCancelled;

  @override
  String toString() => message;
}

class ReceiptParserClient {
  // The public constructor name is kept for dependency injection readability.
  // ignore: prefer_initializing_formals
  ReceiptParserClient({required ApiClient apiClient}) : _apiClient = apiClient;

  static const _endpoint = '/api/v1/parse-receipt';
  final ApiClient _apiClient;

  Future<ReceiptParseResult> parse(
    String ocrText, {
    CancelToken? cancelToken,
  }) async {
    if (ocrText.trim().isEmpty) {
      throw const ReceiptParserException(
        'Fiş üzerinde okunabilir bir metin bulunamadı. Lütfen fişi tekrar çekin veya bilgileri elle girin.',
        kind: ReceiptParserFailureKind.emptyOcr,
      );
    }

    try {
      debugPrint('Receipt API POST: $_endpoint');
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        _endpoint,
        data: {'ocr_text': ocrText},
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) {
        throw const ReceiptParserException(
          'Fiş servisi boş yanıt verdi. Lütfen tekrar deneyin.',
          kind: ReceiptParserFailureKind.invalidResponse,
        );
      }
      return ReceiptParseResult.fromJson(body);
    } on ReceiptParserException {
      rethrow;
    } on DioException catch (error) {
      debugPrint('Receipt API connection error ($_endpoint): $error');
      final fallback = _tryLocalFallback(ocrText);
      if (fallback != null) return fallback;
      throw _mapDioError(error);
    } on FormatException {
      throw const ReceiptParserException(
        'Fiş servisi geçersiz yanıt verdi. Lütfen tekrar deneyin.',
        kind: ReceiptParserFailureKind.invalidResponse,
      );
    }
  }

  ReceiptParserException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return const ReceiptParserException(
        'Fiş analizi iptal edildi.',
        kind: ReceiptParserFailureKind.cancelled,
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return const ReceiptParserException(
        'Fiş analizi beklenenden uzun sürdü. Bağlantınızı kontrol edip tekrar deneyin.',
        kind: ReceiptParserFailureKind.timeout,
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 501) {
      return const ReceiptParserException(
        'Fiş analiz servisi şu anda yanıt veremiyor. Lütfen biraz sonra tekrar deneyin.',
        kind: ReceiptParserFailureKind.geminiUnavailable,
      );
    }
    if (statusCode == 503) {
      return const ReceiptParserException(
        'Fiş servisi yapılandırması şu anda hazır değil. Lütfen daha sonra tekrar deneyin.',
        kind: ReceiptParserFailureKind.serviceConfiguration,
      );
    }
    if (statusCode == 502) {
      return const ReceiptParserException(
        'Fiş servisine şu anda ulaşılamıyor. Lütfen tekrar deneyin.',
        kind: ReceiptParserFailureKind.serviceUnavailable,
      );
    }
    if (statusCode != null) {
      return const ReceiptParserException(
        'Fiş bilgileri işlenirken bir sorun oluştu. Lütfen tekrar deneyin.',
        kind: ReceiptParserFailureKind.serviceUnavailable,
      );
    }

    final details = '${error.error} ${error.message}'.toLowerCase();
    if (error.error is SocketException ||
        details.contains('failed host lookup') ||
        details.contains('host lookup') ||
        details.contains('name or service not known')) {
      return const ReceiptParserException(
        'Fiş servisine ulaşılamadı. Sunucu adresini kontrol edin.',
        kind: ReceiptParserFailureKind.dns,
      );
    }
    return const ReceiptParserException(
      'İnternet bağlantısı bulunamadı. Bağlantınızı kontrol edip tekrar deneyin.',
      kind: ReceiptParserFailureKind.noInternet,
    );
  }

  ReceiptParseResult? _tryLocalFallback(String ocrText) {
    final lines = ocrText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final amountMatches = RegExp(
      r'\d{1,3}(?:[.\s]\d{3})*[,\.]\d{2}|\d+[,\.]\d{1,2}',
    ).allMatches(ocrText).toList();
    if (amountMatches.isEmpty) return null;

    final amountInMinor = _toMinor(amountMatches.last.group(0)!);
    final merchant = lines.first;
    if (amountInMinor == null ||
        merchant.length < 2 ||
        !RegExp(r'[A-Za-z0-9]').hasMatch(merchant)) {
      return null;
    }

    return ReceiptParseResult(
      draft: TransactionDraft(
        institutionName: merchant,
        category: 'Diğer',
        amountInMinor: amountInMinor,
      ),
      normalizedOcrText: ocrText.trim(),
      confidenceScore: .35,
      isParseSuccessful: false,
      usedLocalFallback: true,
    );
  }

  int? _toMinor(String amount) {
    final normalized = amount
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final match = RegExp(r'^(\d+)\.(\d{1,2})$').firstMatch(normalized);
    if (match == null) return null;
    final fraction = match.group(2)!;
    return (int.parse(match.group(1)!) * 100) +
        int.parse(fraction.length == 1 ? '${fraction}0' : fraction);
  }
}
