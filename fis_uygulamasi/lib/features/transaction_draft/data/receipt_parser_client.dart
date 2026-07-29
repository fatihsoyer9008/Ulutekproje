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
  });

  final TransactionDraft draft;
  final String normalizedOcrText;
  final double confidenceScore;
  final bool isParseSuccessful;

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
        'Backend cevabı beklenen formatta değil.',
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

class ReceiptParserException implements Exception {
  const ReceiptParserException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptParserClient {
  // ignore: prefer_initializing_formals
  ReceiptParserClient({required ApiClient apiClient}) : _apiClient = apiClient;

  static const _endpoint = '/api/v1/parse-receipt';
  final ApiClient _apiClient;

  Future<ReceiptParseResult> parse(String ocrText) async {
    if (ocrText.trim().isEmpty) {
      throw const ReceiptParserException('OCR metni boş olamaz.');
    }

    try {
      debugPrint('Receipt API POST: $_endpoint');
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        _endpoint,
        data: {'ocr_text': ocrText},
      );
      final body = response.data;
      if (body == null) {
        throw const ReceiptParserException('Fiş servisi boş cevap döndürdü.');
      }
      return ReceiptParseResult.fromJson(body);
    } on ReceiptParserException {
      rethrow;
    } on DioException catch (error) {
      debugPrint('Receipt API bağlantı hatası ($_endpoint): $error');
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        throw ReceiptParserException(
          'Fiş servisi $statusCode koduyla yanıt verdi.',
        );
      }
      throw ReceiptParserException(
        'Fiş servisine bağlanılamadı: ${error.message}',
      );
    } on FormatException catch (error) {
      throw ReceiptParserException(
        'Fiş servisi geçersiz JSON döndürdü: $error',
      );
    }
  }
}
