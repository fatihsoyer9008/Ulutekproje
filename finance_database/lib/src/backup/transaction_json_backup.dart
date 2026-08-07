import 'dart:convert';

import '../models/receipt_line_item_entity.dart';
import '../models/transaction_entity.dart';

class TransactionJsonImportException implements Exception {
  const TransactionJsonImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TransactionImportResult {
  const TransactionImportResult({
    required this.selectedCount,
    required this.importedCount,
    required this.skippedDuplicateCount,
  });

  final int selectedCount;
  final int importedCount;
  final int skippedDuplicateCount;
}

abstract final class TransactionJsonBackup {
  static const supportedSchemaVersion = 2;

  static List<TransactionEntity> decode(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const TransactionJsonImportException(
        'Seçilen dosya geçerli bir JSON dosyası değil.',
      );
    }

    final rows = _transactionRows(decoded);
    return List<TransactionEntity>.generate(
      rows.length,
      (index) => _decodeTransaction(rows[index], index),
      growable: false,
    );
  }

  static List<dynamic> _transactionRows(dynamic decoded) {
    if (decoded is List<dynamic>) return decoded;
    if (decoded is! Map<String, dynamic>) {
      throw const TransactionJsonImportException(
        'JSON kökünde bir işlem listesi bulunamadı.',
      );
    }

    final schemaVersion = decoded['schemaVersion'] ?? decoded['version'];
    if (schemaVersion != null) {
      if (schemaVersion is! int) {
        throw const TransactionJsonImportException(
          'JSON şema sürümü geçersiz.',
        );
      }
      if (schemaVersion > supportedSchemaVersion) {
        throw TransactionJsonImportException(
          'Bu yedek daha yeni bir şema sürümü kullanıyor: $schemaVersion.',
        );
      }
    }

    final rows = decoded['transactions'] ?? decoded['items'];
    if (rows is! List<dynamic>) {
      throw const TransactionJsonImportException(
        'JSON içinde "transactions" işlem listesi bulunamadı.',
      );
    }
    return rows;
  }

  static TransactionEntity _decodeTransaction(dynamic raw, int index) {
    if (raw is! Map<String, dynamic>) {
      throw TransactionJsonImportException(
        '${index + 1}. işlem bir JSON nesnesi değil.',
      );
    }

    final transactionType = _readEnum(
      raw,
      const ['transactionType', 'transaction_type'],
      TransactionType.values,
      index,
    );
    final amountInMinor = _readInt(raw, const [
      'amountInMinor',
      'amount_in_minor',
    ], index);
    if (amountInMinor <= 0) {
      throw TransactionJsonImportException(
        '${index + 1}. işlemde tutar sıfırdan büyük olmalıdır.',
      );
    }

    final category = _readEnum(
      raw,
      const ['category'],
      TransactionCategory.values,
      index,
    );
    final date = _readDate(raw, const ['date'], index);
    final source = _readEnum(
      raw,
      const ['source'],
      TransactionSource.values,
      index,
    );
    final createdAt =
        _readOptionalDate(raw, const ['createdAt', 'created_at'], index) ??
        date;
    final updatedAt =
        _readOptionalDate(raw, const ['updatedAt', 'updated_at'], index) ??
        createdAt;
    final syncState =
        _readOptionalEnum(
          raw,
          const ['syncState', 'sync_state'],
          SyncState.values,
          index,
        ) ??
        SyncState.localOnly;

    final transaction = TransactionEntity()
      ..transactionType = transactionType
      ..amountInMinor = amountInMinor
      ..category = category
      ..categoryName = _readOptionalString(raw, const [
        'categoryName',
        'category_name',
      ], index)
      ..date = date
      ..merchantName = _readOptionalString(raw, const [
        'merchantName',
        'merchant_name',
      ], index)
      ..source = source
      ..clientRecordId = _readOptionalString(raw, const [
        'clientRecordId',
        'client_record_id',
      ], index)
      ..ownerKey = _readOptionalString(raw, const [
        'ownerKey',
        'owner_key',
      ], index)
      ..syncState = syncState
      ..rawOcrText = _readOptionalString(raw, const [
        'rawOcrText',
        'raw_ocr_text',
      ], index)
      ..note = _readOptionalString(raw, const ['note'], index)
      ..createdAt = createdAt
      ..updatedAt = updatedAt;
    transaction
      ..receiptLineItems = _readReceiptItems(raw, index)
      ..receiptLineItemsLoaded = true;
    return transaction;
  }

  static List<ReceiptLineItemEntity> _readReceiptItems(
    Map<String, dynamic> transaction,
    int transactionIndex,
  ) {
    final value = _optionalValue(transaction, const [
      'receiptItems',
      'receipt_items',
      'lineItems',
      'line_items',
    ]);
    if (value == null) return [];
    if (value is! List<dynamic>) {
      throw TransactionJsonImportException(
        '${transactionIndex + 1}. işlemde "receiptItems" liste olmalıdır.',
      );
    }

    return List<ReceiptLineItemEntity>.generate(value.length, (itemIndex) {
      final rawItem = value[itemIndex];
      if (rawItem is! Map<String, dynamic>) {
        throw TransactionJsonImportException(
          '${transactionIndex + 1}. işlemin ${itemIndex + 1}. ürünü geçersiz.',
        );
      }
      final name = _readItemString(
        rawItem,
        const ['name'],
        transactionIndex,
        itemIndex,
        required: true,
      )!;

      return ReceiptLineItemEntity()
        ..transactionId = 0
        ..position = itemIndex
        ..name = name
        ..category = _readItemString(
          rawItem,
          const ['category'],
          transactionIndex,
          itemIndex,
        )
        ..priceInMinor = _readItemInt(
          rawItem,
          const ['priceInMinor', 'price_in_minor', 'price_minor'],
          transactionIndex,
          itemIndex,
        )
        ..totalAmountInMinor = _readItemInt(
          rawItem,
          const ['totalAmountInMinor', 'total_amount_in_minor'],
          transactionIndex,
          itemIndex,
        )
        ..quantity = _readItemDouble(
          rawItem,
          const ['quantity'],
          transactionIndex,
          itemIndex,
        )
        ..unitPriceInMinor = _readItemInt(
          rawItem,
          const ['unitPriceInMinor', 'unit_price_in_minor'],
          transactionIndex,
          itemIndex,
        )
        ..taxRate = _readItemDouble(
          rawItem,
          const ['taxRate', 'tax_rate'],
          transactionIndex,
          itemIndex,
        )
        ..taxAmountInMinor = _readItemInt(
          rawItem,
          const ['taxAmountInMinor', 'tax_amount_in_minor'],
          transactionIndex,
          itemIndex,
        );
    }, growable: false);
  }

  static String? _readItemString(
    Map<String, dynamic> item,
    List<String> keys,
    int transactionIndex,
    int itemIndex, {
    bool required = false,
  }) {
    final value = _optionalValue(item, keys);
    if (value == null && !required) return null;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw TransactionJsonImportException(
      '${transactionIndex + 1}. işlemin ${itemIndex + 1}. ürününde '
      '"${keys.first}" geçersiz.',
    );
  }

  static int? _readItemInt(
    Map<String, dynamic> item,
    List<String> keys,
    int transactionIndex,
    int itemIndex,
  ) {
    final value = _optionalValue(item, keys);
    if (value == null) return null;
    if (value is int && value >= 0) return value;
    throw TransactionJsonImportException(
      '${transactionIndex + 1}. işlemin ${itemIndex + 1}. ürününde '
      '"${keys.first}" negatif olmayan tam sayı olmalıdır.',
    );
  }

  static double? _readItemDouble(
    Map<String, dynamic> item,
    List<String> keys,
    int transactionIndex,
    int itemIndex,
  ) {
    final value = _optionalValue(item, keys);
    if (value == null) return null;
    if (value is num && value.isFinite && value >= 0) return value.toDouble();
    throw TransactionJsonImportException(
      '${transactionIndex + 1}. işlemin ${itemIndex + 1}. ürününde '
      '"${keys.first}" negatif olmayan sayı olmalıdır.',
    );
  }

  static T _readEnum<T extends Enum>(
    Map<String, dynamic> map,
    List<String> keys,
    List<T> values,
    int index,
  ) {
    final value = _requiredValue(map, keys, index);
    if (value is String) {
      for (final candidate in values) {
        if (candidate.name == value) return candidate;
      }
    }
    throw TransactionJsonImportException(
      '${index + 1}. işlemde "${keys.first}" değeri geçersiz.',
    );
  }

  static T? _readOptionalEnum<T extends Enum>(
    Map<String, dynamic> map,
    List<String> keys,
    List<T> values,
    int index,
  ) {
    final value = _optionalValue(map, keys);
    if (value == null) return null;
    if (value is String) {
      for (final candidate in values) {
        if (candidate.name == value) return candidate;
      }
    }
    throw TransactionJsonImportException(
      '${index + 1}. işlemde "${keys.first}" değeri geçersiz.',
    );
  }

  static int _readInt(Map<String, dynamic> map, List<String> keys, int index) {
    final value = _requiredValue(map, keys, index);
    if (value is int) return value;
    throw TransactionJsonImportException(
      '${index + 1}. işlemde "${keys.first}" tam sayı olmalıdır.',
    );
  }

  static DateTime _readDate(
    Map<String, dynamic> map,
    List<String> keys,
    int index,
  ) {
    final value = _requiredValue(map, keys, index);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw TransactionJsonImportException(
      '${index + 1}. işlemde "${keys.first}" ISO-8601 tarih olmalıdır.',
    );
  }

  static DateTime? _readOptionalDate(
    Map<String, dynamic> map,
    List<String> keys,
    int index,
  ) {
    final value = _optionalValue(map, keys);
    if (value == null) return null;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw TransactionJsonImportException(
      '${index + 1}. işlemde "${keys.first}" ISO-8601 tarih olmalıdır.',
    );
  }

  static String? _readOptionalString(
    Map<String, dynamic> map,
    List<String> keys,
    int index,
  ) {
    final value = _optionalValue(map, keys);
    if (value == null) return null;
    if (value is String) return value;
    throw TransactionJsonImportException(
      '${index + 1}. işlemde "${keys.first}" metin olmalıdır.',
    );
  }

  static dynamic _requiredValue(
    Map<String, dynamic> map,
    List<String> keys,
    int index,
  ) {
    final value = _optionalValue(map, keys);
    if (value != null) return value;
    throw TransactionJsonImportException(
      '${index + 1}. işlemde "${keys.first}" alanı eksik.',
    );
  }

  static dynamic _optionalValue(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) return map[key];
    }
    return null;
  }
}
