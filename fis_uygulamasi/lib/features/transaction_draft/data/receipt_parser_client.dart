import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/transaction_draft.dart';

class ReceiptParseResult {
  const ReceiptParseResult({
    required this.draft,
    required this.confidenceScore,
    required this.isParseSuccessful,
  });

  final TransactionDraft draft;
  final double confidenceScore;
  final bool isParseSuccessful;

  factory ReceiptParseResult.fromJson(Map<String, dynamic> json) {
    final confidence = json['confidence_score'];
    final successful = json['is_parse_successful'];
    if (confidence is! num ||
        confidence < 0 ||
        confidence > 1 ||
        successful is! bool) {
      throw const ReceiptParserException(
        'Backend cevabı beklenen formatta değil.',
      );
    }

    return ReceiptParseResult(
      draft: TransactionDraft.fromJson(json),
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
      response = await _client
          .post(
            _endpoint,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'ocr_text': ocrText}),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (error) {
      throw ReceiptParserException('Fiş servisine bağlanılamadı: $error');
    }

    if (response.statusCode != 200) {
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
