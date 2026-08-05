import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/installation_id_provider.dart';

abstract interface class PendingTaskSyncGateway {
  Future<void> send(OfflineTask task);
}

class SyncConflictException implements Exception {
  const SyncConflictException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DioPendingTaskSyncGateway implements PendingTaskSyncGateway {
  DioPendingTaskSyncGateway({
    required this.apiClient,
    required this.installationIdProvider,
  });

  final ApiClient apiClient;
  final InstallationIdProvider installationIdProvider;

  @override
  Future<void> send(OfflineTask task) async {
    final decoded = jsonDecode(task.payloadJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Pending task payload bir JSON nesnesi olmalı.',
      );
    }

    final operation = _asPushOperation(task, decoded);

    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/sync/push',
      data: {
        'installation_id': await installationIdProvider.getInstallationId(),
        'operations': [operation],
      },
    );
    _validatePushResponse(task, operation, response.data);
  }

  void _validatePushResponse(
    OfflineTask task,
    Map<String, dynamic> operation,
    Map<String, dynamic>? body,
  ) {
    final results = body?['results'];
    if (results is! List || results.length != 1) {
      throw const FormatException('Sync cevabı tek bir sonuç içermeli.');
    }
    final result = results.single;
    if (result is! Map) {
      throw const FormatException('Sync sonucu geçersiz.');
    }
    final expectedOperationId = operation['operation_id'] ?? task.clientTaskId;
    if (result['operation_id'] != expectedOperationId) {
      throw const FormatException('Sync sonucu farklı bir operasyona ait.');
    }
    final status = result['status'];
    if (status == 'conflict') {
      throw SyncConflictException(
        'Sunucudaki daha güncel kayıt nedeniyle çakışma oluştu.',
      );
    }
    const successfulStatuses = {'created', 'updated', 'unchanged', 'deleted'};
    if (status is! String || !successfulStatuses.contains(status)) {
      throw FormatException('Bilinmeyen sync sonucu: $status');
    }
  }

  Map<String, dynamic> _asPushOperation(
    OfflineTask task,
    Map<String, dynamic> payload,
  ) {
    // Kuyruğa tam bir push operation yazılmışsa aynen gönderilir.
    if (payload.containsKey('operation_id') && payload.containsKey('action')) {
      return payload;
    }

    final isDelete = task.type == OfflineTaskType.deleteTransaction;
    final clientRecordId = payload['client_record_id'];
    final clientUpdatedAt = payload['client_updated_at'];

    if (clientRecordId is! String || clientUpdatedAt is! String) {
      throw const FormatException(
        'Payload client_record_id ve client_updated_at alanlarını içermeli.',
      );
    }

    return {
      'operation_id': task.clientTaskId,
      'action': isDelete ? 'delete' : 'upsert',
      'client_record_id': clientRecordId,
      'client_updated_at': clientUpdatedAt,
      'transaction': isDelete ? null : payload,
    };
  }
}

bool isUnrecoverableSyncError(Object error) {
  if (error is FormatException || error is SyncConflictException) return true;

  if (error is DioException) {
    final status = error.response?.statusCode;
    return status != null &&
        status >= 400 &&
        status < 500 &&
        status != 408 &&
        status != 429;
  }

  return false;
}
