import '../../../core/network/api_client.dart';
import '../domain/pending_receipt.dart';

abstract interface class PendingReceiptsGateway {
  Future<List<PendingReceipt>> list();

  Future<PendingReceipt> approve(
    String id, {
    String? merchantName,
    int? totalAmountInMinor,
    String? currency,
    DateTime? receiptDate,
    String? category,
  });

  Future<PendingReceipt> reject(String id);
}

class DioPendingReceiptsGateway implements PendingReceiptsGateway {
  DioPendingReceiptsGateway({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<List<PendingReceipt>> list() async {
    final response = await apiClient.dio.get<List<dynamic>>(
      '/api/v1/receipts/pending',
    );
    final items = response.data ?? const [];
    return items
        .map(
          (item) =>
              PendingReceipt.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<PendingReceipt> approve(
    String id, {
    String? merchantName,
    int? totalAmountInMinor,
    String? currency,
    DateTime? receiptDate,
    String? category,
  }) async {
    final body = <String, dynamic>{
      'merchant_name': ?merchantName,
      'total_amount_in_minor': ?totalAmountInMinor,
      'currency': ?currency,
      if (receiptDate != null)
        'receipt_date': receiptDate.toUtc().toIso8601String(),
      'category': ?category,
    };
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/receipts/$id/approve',
      data: body,
    );
    return PendingReceipt.fromJson(response.data!);
  }

  @override
  Future<PendingReceipt> reject(String id) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/receipts/$id/reject',
    );
    return PendingReceipt.fromJson(response.data!);
  }
}
