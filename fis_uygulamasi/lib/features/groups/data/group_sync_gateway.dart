import 'dart:collection';
import 'dart:convert';

import 'package:finance_database/finance_database.dart';
import 'package:dio/dio.dart';

enum GroupPushStatus { accepted, duplicate, conflict }

class GroupPushResult {
  const GroupPushResult({
    required this.operationId,
    required this.status,
    this.message,
    this.conflictCode,
  });

  final String operationId;
  final GroupPushStatus status;
  final String? message;
  final String? conflictCode;
}

class GroupPullChange {
  const GroupPullChange({
    required this.cursor,
    required this.operation,
    required this.serverUpdatedAt,
  });

  final String cursor;
  final Map<String, Object?> operation;
  final DateTime serverUpdatedAt;
}

class GroupPullBatch {
  const GroupPullBatch({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<GroupPullChange> changes;
  final String? nextCursor;
  final bool hasMore;
}

abstract interface class GroupPushGateway {
  Future<GroupPushResult> push(OfflineTask task);
}

abstract interface class GroupPullGateway {
  Future<GroupPullBatch> pull({String? cursor});
}

/// Production gateway. Kuyruk zarfını backend'in mevcut, idempotent grup
/// endpointlerine yönlendirir; retry sırasında task.clientTaskId değişmez.
class DioGroupPushGateway implements GroupPushGateway {
  const DioGroupPushGateway(this._dio);

  final Dio _dio;

  @override
  Future<GroupPushResult> push(OfflineTask task) async {
    final envelope = _taskEnvelope(task);
    final ownerKey = envelope['owner_key'];
    if (ownerKey is! String || !ownerKey.startsWith('user:')) {
      throw const GroupSyncPermanentException(
        'Geçersiz grup sync owner scope.',
      );
    }
    if (envelope['client_record_id'] != task.clientTaskId) {
      throw const GroupSyncPermanentException('Sync tracking ID uyuşmuyor.');
    }
    final groupId = envelope['group_id'];
    final rawPayload = envelope['sync_payload'] ?? envelope['payload'];
    if (groupId is! String || rawPayload is! Map) {
      throw const GroupSyncPermanentException('Grup sync payload geçersiz.');
    }
    final payload = Map<String, Object?>.from(rawPayload);
    if (task.type == OfflineTaskType.settlementCreate) {
      payload.remove('id');
      payload.remove('group_id');
      payload.remove('created_at');
    }

    switch (task.type) {
      case OfflineTaskType.groupExpenseCreate:
      case OfflineTaskType.expenseShareCreate:
      case OfflineTaskType.expenseShareUpdate:
      case OfflineTaskType.expenseShareDelete:
      case OfflineTaskType.settlementCreate:
        break;
      default:
        throw const GroupSyncPermanentException(
          'Bu grup operasyonu production gateway tarafından desteklenmiyor.',
        );
    }
    final requestEnvelope = Map<String, Object?>.from(envelope)
      ..['sync_payload'] = payload;
    try {
      final response = await _dio.post<Object?>(
        '/api/v1/sync/groups/push',
        data: requestEnvelope,
        options: Options(headers: {'Idempotency-Key': task.clientTaskId}),
      );
      final responseBody = response.data;
      final responseStatus = responseBody is Map
          ? responseBody['status']
          : null;
      final operationId = responseBody is Map
          ? responseBody['operation_id']
          : null;
      if (operationId != null && operationId != task.clientTaskId) {
        throw const GroupSyncPermanentException(
          'Sync endpoint farklı bir operasyon kimliği döndürdü.',
        );
      }
      final replayed =
          response.headers.value('Idempotency-Replayed')?.toLowerCase() ==
              'true' ||
          responseStatus == 'duplicate';
      return GroupPushResult(
        operationId: task.clientTaskId,
        status: replayed ? GroupPushStatus.duplicate : GroupPushStatus.accepted,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final message = _errorMessage(error.response?.data);
      if (status == 409) {
        final code = _errorCode(error.response?.data);
        return GroupPushResult(
          operationId: task.clientTaskId,
          status: GroupPushStatus.conflict,
          message: _conflictMessage(code, message),
          conflictCode: code,
        );
      }
      if (status != null && status >= 400 && status < 500) {
        throw GroupSyncPermanentException(
          message ?? 'Grup sync isteği sunucu tarafından reddedildi ($status).',
        );
      }
      throw GroupSyncTemporaryException(
        message ?? 'Grup sync endpointine geçici olarak ulaşılamıyor.',
      );
    }
  }

  static Map<String, Object?> _taskEnvelope(OfflineTask task) {
    try {
      final value = jsonDecode(task.payloadJson);
      if (value is Map) return Map<String, Object?>.from(value);
    } on FormatException {
      // Aşağıdaki kalıcı hata tek biçimli hata raporu üretir.
    }
    throw const GroupSyncPermanentException('Grup sync zarfı geçersiz JSON.');
  }

  static String? _errorMessage(Object? data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        return error['message']! as String;
      }
    }
    return null;
  }

  static String? _errorCode(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is Map && detail['code'] is String) {
      return detail['code']! as String;
    }
    final error = data['error'];
    if (error is Map && error['code'] is String) {
      return error['code']! as String;
    }
    return null;
  }

  static String _conflictMessage(
    String? code,
    String? serverMessage,
  ) => switch (code) {
    'expense_financially_locked' || 'expense_locked_by_settlement' =>
      'Masraf borç kapatma işleminden sonra finansal olarak kilitlendi.',
    'expense_soft_deleted' || 'record_soft_deleted' =>
      'Bu kayıt sunucuda silinmiş olduğu için işlem uygulanamadı.',
    'version_conflict' || 'version_mismatch' =>
      'Kayıt başka bir cihazda güncellendi. Güncel veriyi yükleyip yeniden deneyin.',
    'idempotency_conflict' =>
      'Aynı işlem kimliği daha önce farklı bilgilerle kullanıldı.',
    _ => serverMessage ?? 'Finansal kayıt sunucudaki sürümle çakıştı.',
  };
}

class NoopGroupPullGateway implements GroupPullGateway {
  const NoopGroupPullGateway();

  @override
  Future<GroupPullBatch> pull({String? cursor}) async =>
      GroupPullBatch(changes: const [], nextCursor: cursor, hasMore: false);
}

class GroupSyncTemporaryException implements Exception {
  const GroupSyncTemporaryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GroupSyncPermanentException implements Exception {
  const GroupSyncPermanentException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum FakeGroupPushOutcome {
  accept,
  temporaryFailure,
  conflict,
  permanentFailure,
}

/// Gerçek backend endpoint'i hazır olana kadar idempotency, hata, conflict ve
/// cursor tabanlı pull davranışlarını bellek içinde simüle eder.
class FakeGroupSyncServer {
  FakeGroupSyncServer({this.pageSize = 50, DateTime Function()? clock})
    : assert(pageSize > 0),
      _clock = clock ?? (() => DateTime.now().toUtc());

  final int pageSize;
  final DateTime Function() _clock;
  final Map<String, String> _acceptedPayloads = <String, String>{};
  final Map<String, Queue<FakeGroupPushOutcome>> _scheduledOutcomes =
      <String, Queue<FakeGroupPushOutcome>>{};
  final List<_StoredGroupChange> _changes = <_StoredGroupChange>[];
  int _sequence = 0;

  int get acceptedOperationCount => _acceptedPayloads.length;

  void enqueuePushOutcome(String clientTaskId, FakeGroupPushOutcome outcome) {
    _scheduledOutcomes
        .putIfAbsent(clientTaskId, Queue<FakeGroupPushOutcome>.new)
        .add(outcome);
  }

  void seedRemoteOperation(Map<String, Object?> operation) {
    final snapshot = _validatedOperation(operation);
    _acceptedPayloads[snapshot['client_record_id']! as String] = _canonicalJson(
      snapshot,
    );
    _appendChange(snapshot);
  }

  Future<GroupPushResult> push(OfflineTask task) async {
    final operation = _decodeTask(task);
    final scheduled = _scheduledOutcomes[task.clientTaskId];
    final outcome = scheduled == null || scheduled.isEmpty
        ? FakeGroupPushOutcome.accept
        : scheduled.removeFirst();

    switch (outcome) {
      case FakeGroupPushOutcome.temporaryFailure:
        throw const GroupSyncTemporaryException(
          'Geçici fake grup sunucusu hatası.',
        );
      case FakeGroupPushOutcome.conflict:
        return GroupPushResult(
          operationId: task.clientTaskId,
          status: GroupPushStatus.conflict,
          message: 'Fake sunucuda daha güncel grup kaydı bulunuyor.',
        );
      case FakeGroupPushOutcome.permanentFailure:
        throw const GroupSyncPermanentException(
          'Fake grup operasyonu kalıcı olarak reddedildi.',
        );
      case FakeGroupPushOutcome.accept:
        break;
    }

    final canonicalPayload = _canonicalJson(operation);
    final existing = _acceptedPayloads[task.clientTaskId];
    if (existing != null) {
      if (existing == canonicalPayload) {
        return GroupPushResult(
          operationId: task.clientTaskId,
          status: GroupPushStatus.duplicate,
        );
      }
      return GroupPushResult(
        operationId: task.clientTaskId,
        status: GroupPushStatus.conflict,
        message: 'Aynı clientRecordId farklı payload ile tekrar kullanıldı.',
      );
    }

    _acceptedPayloads[task.clientTaskId] = canonicalPayload;
    _appendChange(operation);
    return GroupPushResult(
      operationId: task.clientTaskId,
      status: GroupPushStatus.accepted,
    );
  }

  Future<GroupPullBatch> pull({String? cursor}) async {
    final after = _parseCursor(cursor);
    final available = _changes.where((change) => change.sequence > after);
    final page = available.take(pageSize).toList(growable: false);
    final nextCursor = page.isEmpty ? cursor : page.last.sequence.toString();
    final hasMore = _changes.any(
      (change) => change.sequence > (page.isEmpty ? after : page.last.sequence),
    );
    return GroupPullBatch(
      changes: page
          .map(
            (change) => GroupPullChange(
              cursor: change.sequence.toString(),
              operation: _jsonClone(change.operation),
              serverUpdatedAt: change.serverUpdatedAt,
            ),
          )
          .toList(growable: false),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  Map<String, Object?> _decodeTask(OfflineTask task) {
    if (!task.type.isGroupOperation) {
      throw const GroupSyncPermanentException(
        'Kişisel transaction fake grup gateway üzerinden gönderilemez.',
      );
    }
    final decoded = jsonDecode(task.payloadJson);
    if (decoded is! Map) {
      throw const FormatException('Grup task payload bir JSON nesnesi olmalı.');
    }
    final operation = Map<String, Object?>.from(decoded);
    final validated = _validatedOperation(operation);
    if (validated['operation_type'] != task.type.name ||
        validated['client_record_id'] != task.clientTaskId) {
      throw const GroupSyncPermanentException(
        'OfflineTask alanları grup operation payload ile eşleşmiyor.',
      );
    }
    return validated;
  }

  Map<String, Object?> _validatedOperation(Map<String, Object?> operation) {
    final typeName = operation['operation_type'];
    final clientRecordId = operation['client_record_id'];
    final ownerKey = operation['owner_key'];
    if (typeName is! String ||
        clientRecordId is! String ||
        ownerKey is! String ||
        !ownerKey.startsWith('user:') ||
        operation['group_id'] is! String ||
        operation['payload'] is! Map) {
      throw const FormatException('Grup operation payload alanları geçersiz.');
    }
    final type = OfflineTaskType.values
        .where((candidate) => candidate.name == typeName)
        .firstOrNull;
    if (type == null || !type.isGroupOperation) {
      throw const FormatException('Bilinmeyen grup operation türü.');
    }
    return _jsonClone(operation);
  }

  void _appendChange(Map<String, Object?> operation) {
    _sequence += 1;
    _changes.add(
      _StoredGroupChange(
        sequence: _sequence,
        operation: _jsonClone(operation),
        serverUpdatedAt: _clock(),
      ),
    );
  }

  int _parseCursor(String? cursor) {
    if (cursor == null) return 0;
    final parsed = int.tryParse(cursor);
    if (parsed == null || parsed < 0 || parsed > _sequence) {
      throw const FormatException('Fake pull cursor geçersiz.');
    }
    return parsed;
  }
}

class FakeGroupPushGateway implements GroupPushGateway {
  const FakeGroupPushGateway(this.server);

  final FakeGroupSyncServer server;

  @override
  Future<GroupPushResult> push(OfflineTask task) => server.push(task);
}

class FakeGroupPullGateway implements GroupPullGateway {
  const FakeGroupPullGateway(this.server);

  final FakeGroupSyncServer server;

  @override
  Future<GroupPullBatch> pull({String? cursor}) => server.pull(cursor: cursor);
}

class _StoredGroupChange {
  const _StoredGroupChange({
    required this.sequence,
    required this.operation,
    required this.serverUpdatedAt,
  });

  final int sequence;
  final Map<String, Object?> operation;
  final DateTime serverUpdatedAt;
}

Map<String, Object?> _jsonClone(Map<String, Object?> source) =>
    Map<String, Object?>.from(jsonDecode(jsonEncode(source))! as Map);

String _canonicalJson(Map<String, Object?> source) =>
    jsonEncode(_canonicalJsonValue(source));

Object? _canonicalJsonValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalJsonValue(value[key]),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) _canonicalJsonValue(item)];
  }
  return value;
}
