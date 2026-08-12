import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/installation_id_provider.dart';
import '../application/itemized_split_calculator.dart';
import '../presentation/itemized_split_page.dart';

class ReceiptSyncRepository {
  const ReceiptSyncRepository({
    required this.apiClient,
    required this.installationIdProvider,
  });

  final ApiClient apiClient;
  final InstallationIdProvider installationIdProvider;

  Future<ItemizedSplitReceipt?> syncLatestReceipt(
    Iterable<TransactionEntity> transactions,
  ) async {
    final candidates =
        transactions
            .where(
              (transaction) =>
                  transaction.transactionType == TransactionType.expense &&
                  transaction.clientRecordId?.trim().isNotEmpty == true &&
                  transaction.receiptLineItems.isNotEmpty &&
                  transaction.receiptLineItems.every(
                    (item) =>
                        (item.totalAmountInMinor ?? item.priceInMinor) != null,
                  ),
            )
            .toList()
          ..sort((left, right) => right.date.compareTo(left.date));
    if (candidates.isEmpty) return null;
    return syncReceipt(candidates.first);
  }

  Future<ItemizedSplitReceipt> syncReceipt(
    TransactionEntity transaction,
  ) async {
    final clientRecordId = transaction.clientRecordId;
    if (clientRecordId == null || clientRecordId.trim().isEmpty) {
      throw const FormatException('Fişin bulut kayıt kimliği bulunamadı.');
    }
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/receipts/sync',
      data: <String, Object?>{
        'client_record_id': clientRecordId,
        'merchant_name': transaction.merchantName,
        'total_amount_in_minor': transaction.amountInMinor,
        'currency': 'TRY',
        'receipt_date': transaction.date.toUtc().toIso8601String(),
        'category': transaction.categoryName ?? transaction.category.name,
        'raw_ocr_text': transaction.rawOcrText,
        'client_created_at': transaction.createdAt.toUtc().toIso8601String(),
        'client_updated_at': transaction.updatedAt.toUtc().toIso8601String(),
        'line_items': [
          for (final item in transaction.receiptLineItems)
            <String, Object?>{
              'position': item.position,
              'name': item.name,
              'total_amount_in_minor':
                  item.totalAmountInMinor ?? item.priceInMinor,
              'quantity_milli': item.quantity == null
                  ? null
                  : (item.quantity! * 1000).round(),
              'unit_price_in_minor': item.unitPriceInMinor,
              'category': item.category,
            },
        ],
      },
      options: Options(
        headers: {
          'X-Installation-ID': await installationIdProvider.getInstallationId(),
        },
      ),
    );
    final body = response.data;
    final lineItems = body?['line_items'];
    if (body == null ||
        body['receipt_id'] is! String ||
        body['total_amount_in_minor'] is! int ||
        lineItems is! List) {
      throw const FormatException('Fiş senkronizasyon cevabı geçersiz.');
    }
    return ItemizedSplitReceipt(
      receiptId: body['receipt_id'] as String,
      totalAmountInMinor: body['total_amount_in_minor'] as int,
      lineItems: [
        for (final raw in lineItems)
          if (raw is Map)
            ItemizedReceiptLine(
              receiptLineItemId: raw['receipt_line_item_id'] as String?,
              name: raw['name'] as String,
              quantityMilli: raw['quantity_milli'] as int?,
              unitPriceInMinor: raw['unit_price_in_minor'] as int?,
              totalAmountInMinor: raw['total_amount_in_minor'] as int?,
            ),
      ],
    );
  }
}
