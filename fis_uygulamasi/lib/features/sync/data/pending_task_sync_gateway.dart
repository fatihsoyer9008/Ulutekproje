import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/installation_id_provider.dart';

abstract interface class PendingTaskSyncGateway {
  Future<void> send(OfflineTask task);
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

    await apiClient.dio.post<Map<String, dynamic>>(
      '/api/v1/sync/push',
      data: {
        'installation_id': await installationIdProvider.getInstallationId(),
        'operations': [operation],
      },
    );
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
  if (error is FormatException) return true;

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
