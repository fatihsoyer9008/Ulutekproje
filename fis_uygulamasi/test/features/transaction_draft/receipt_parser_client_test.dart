import 'dart:convert';

import 'package:app_main/features/transaction_draft/data/receipt_parser_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('posts OCR text and maps the backend response to a draft', () async {
    final httpClient = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/parse-receipt');
      expect(jsonDecode(request.body), {'ocr_text': 'MİGROS TOPLAM 25,50 TL'});

      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'merchant': 'MİGROS',
            'total_amount_minor': 2550,
            'currency': 'TRY',
            'date': '2026-07-28T12:00:00Z',
            'category': 'Market',
            'confidence_score': 0.92,
            'is_parse_successful': true,
            'items': <Object>[],
          }),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final client = ReceiptParserClient(
      baseUrl: 'https://example.com/',
      client: httpClient,
    );

    final result = await client.parse('MİGROS TOPLAM 25,50 TL');

    expect(result.draft.institutionName, 'MİGROS');
    expect(result.draft.category, 'Market');
    expect(result.draft.amountInMinor, 2550);
    expect(result.confidenceScore, 0.92);
    expect(result.isParseSuccessful, isTrue);
    client.close();
  });

  test('throws a readable error for a non-success response', () async {
    final client = ReceiptParserClient(
      baseUrl: 'https://example.com',
      client: MockClient((_) async => http.Response('error', 502)),
    );

    expect(
      () => client.parse('OCR'),
      throwsA(
        isA<ReceiptParserException>().having(
          (error) => error.message,
          'message',
          contains('502'),
        ),
      ),
    );
    client.close();
  });
}
