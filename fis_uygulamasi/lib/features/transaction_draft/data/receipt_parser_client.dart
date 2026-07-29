import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  ReceiptParserClient({required String baseUrl, http.Client? client})
    : _client = client ?? http.Client(),
      _endpoint = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/v1/parse-receipt',
      );

  final http.Client _client;
  final Uri _endpoint;

  Future<ReceiptParseResult> parse(String ocrText) async {
    if (ocrText.trim().isEmpty) {
      throw const ReceiptParserException('OCR metni boş olamaz.');
    }

    late final http.Response response;
    try {
      debugPrint('Receipt API POST: $_endpoint');
      response = await _client
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'ocr_text': ocrText}),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (error) {
      debugPrint('Receipt API bağlantı hatası ($_endpoint): $error');
      throw ReceiptParserException('Fiş servisine bağlanılamadı: $error');
    }

    if (response.statusCode != 200) {
      debugPrint(
        'Receipt API hata cevabı ($_endpoint): ${response.statusCode} ${response.body}',
      );
      throw ReceiptParserException(
        'Fiş servisi ${response.statusCode} koduyla yanıt verdi.',
      );
    }

    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const FormatException('JSON nesnesi bekleniyordu.');
      }
      return ReceiptParseResult.fromJson(body);
    } on ReceiptParserException {
      rethrow;
    } on FormatException catch (error) {
      throw ReceiptParserException(
        'Fiş servisi geçersiz JSON döndürdü: $error',
      );
    }
  }

  void close() => _client.close();
}
