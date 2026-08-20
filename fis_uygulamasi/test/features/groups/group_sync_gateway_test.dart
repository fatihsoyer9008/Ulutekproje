import 'dart:convert';
import 'dart:typed_data';

import 'package:app_main/features/groups/data/group_sync_gateway.dart';
import 'package:dio/dio.dart';
import 'package:finance_database/finance_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake push kabul edilen operasyonu cursor ile pull eder', () async {
    final server = FakeGroupSyncServer(
      clock: () => DateTime.utc(2026, 8, 17, 12),
    );
    final push = FakeGroupPushGateway(server);
    final pull = FakeGroupPullGateway(server);
    final task = _task(1);

    final result = await push.push(task);
    final batch = await pull.pull();

    expect(result.status, GroupPushStatus.accepted);
    expect(batch.changes, hasLength(1));
    expect(
      batch.changes.single.operation['client_record_id'],
      task.clientTaskId,
    );
    expect(batch.changes.single.serverUpdatedAt, DateTime.utc(2026, 8, 17, 12));
    expect(batch.nextCursor, '1');
    expect(batch.hasMore, isFalse);
  });

  test('aynı clientRecordId ve payload idempotent duplicate döner', () async {
    final server = FakeGroupSyncServer();
    final task = _task(1);
    final decoded = jsonDecode(task.payloadJson)! as Map<String, dynamic>;
    final reordered = _task(1)
      ..payloadJson = jsonEncode(<String, Object?>{
        for (final key in decoded.keys.toList().reversed) key: decoded[key],
      });

    final first = await server.push(task);
    final duplicate = await server.push(reordered);
    final pulled = await server.pull();

    expect(first.status, GroupPushStatus.accepted);
    expect(duplicate.status, GroupPushStatus.duplicate);
    expect(server.acceptedOperationCount, 1);
    expect(pulled.changes, hasLength(1));
  });

  test('aynı clientRecordId farklı payload ile conflict döner', () async {
    final server = FakeGroupSyncServer();
    final first = _task(1);
    final changed = _task(1, title: 'Değişen payload');

    await server.push(first);
    final result = await server.push(changed);

    expect(result.status, GroupPushStatus.conflict);
    expect(result.message, contains('farklı payload'));
  });

  test('planlanan geçici, conflict ve kalıcı sonuçları simüle eder', () async {
    final server = FakeGroupSyncServer();
    final temporary = _task(1);
    final conflict = _task(2);
    final permanent = _task(3);
    server
      ..enqueuePushOutcome(
        temporary.clientTaskId,
        FakeGroupPushOutcome.temporaryFailure,
      )
      ..enqueuePushOutcome(conflict.clientTaskId, FakeGroupPushOutcome.conflict)
      ..enqueuePushOutcome(
        permanent.clientTaskId,
        FakeGroupPushOutcome.permanentFailure,
      );

    await expectLater(
      server.push(temporary),
      throwsA(isA<GroupSyncTemporaryException>()),
    );
    expect((await server.push(temporary)).status, GroupPushStatus.accepted);
    expect((await server.push(conflict)).status, GroupPushStatus.conflict);
    await expectLater(
      server.push(permanent),
      throwsA(isA<GroupSyncPermanentException>()),
    );
  });

  test('pull sayfalarını cursor ile kayıpsız dolaşır', () async {
    final server = FakeGroupSyncServer(pageSize: 2);
    for (var index = 1; index <= 5; index++) {
      await server.push(_task(index));
    }

    final first = await server.pull();
    final second = await server.pull(cursor: first.nextCursor);
    final third = await server.pull(cursor: second.nextCursor);

    expect(first.changes, hasLength(2));
    expect(first.hasMore, isTrue);
    expect(second.changes, hasLength(2));
    expect(second.hasMore, isTrue);
    expect(third.changes, hasLength(1));
    expect(third.hasMore, isFalse);
    expect(third.nextCursor, '5');
  });

  test('Dio pull gateway cursor ve değişiklik sayfasını ayrıştırır', () async {
    late RequestOptions captured;
    final gateway = DioGroupPullGateway(
      _dio((options) {
        captured = options;
        return _response(<String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'cursor': '8',
              'operation': <String, Object?>{
                'operation_type': 'groupExpenseDelete',
                'group_id': '92000000-0000-4000-8000-000000000001',
                'client_record_id': '93000000-0000-4000-8000-000000000008',
                'owner_key': 'user:91000000-0000-4000-8000-000000000001',
                'sync_state': 'synced',
                'payload': <String, Object?>{
                  'group_id': '92000000-0000-4000-8000-000000000001',
                  'expense_id': '94000000-0000-4000-8000-000000000008',
                },
              },
              'server_updated_at': '2026-08-17T12:30:00+03:00',
            },
          ],
          'next_cursor': '8',
          'has_more': true,
        });
      }),
    );

    final batch = await gateway.pull(cursor: '7');

    expect(captured.path, '/api/v1/sync/groups/pull');
    expect(captured.queryParameters, <String, Object?>{'cursor': '7'});
    expect(batch.changes, hasLength(1));
    expect(batch.changes.single.cursor, '8');
    expect(
      batch.changes.single.serverUpdatedAt,
      DateTime.utc(2026, 8, 17, 9, 30),
    );
    expect(batch.nextCursor, '8');
    expect(batch.hasMore, isTrue);
  });

  test('Dio pull gateway bozuk yanıtı kalıcı hata sayar', () async {
    final gateway = DioGroupPullGateway(
      _dio((_) => _response(<String, Object?>{'changes': <Object?>[]})),
    );

    await expectLater(
      gateway.pull(),
      throwsA(isA<GroupSyncPermanentException>()),
    );
  });

  test('Dio pull gateway sunucu kesintisini geçici hata sayar', () async {
    final gateway = DioGroupPullGateway(
      _dio(
        (_) => _response(<String, Object?>{
          'detail': <String, Object?>{'message': 'Bakım sürüyor'},
        }, statusCode: 503),
      ),
    );

    await expectLater(
      gateway.pull(),
      throwsA(
        isA<GroupSyncTemporaryException>().having(
          (error) => error.message,
          'message',
          'Bakım sürüyor',
        ),
      ),
    );
  });

  test('kişisel task ve bozuk grup payloadı reddedilir', () async {
    final server = FakeGroupSyncServer();
    final personal = _task(1)..type = OfflineTaskType.createTransaction;
    final malformed = _task(2)..payloadJson = '{}';

    await expectLater(
      server.push(personal),
      throwsA(isA<GroupSyncPermanentException>()),
    );
    await expectLater(server.push(malformed), throwsA(isA<FormatException>()));
  });

  test('Dio gateway expense payloadını clientRecordId ile gönderir', () async {
    late RequestOptions captured;
    final gateway = DioGroupPushGateway(
      _dio((options) {
        captured = options;
        return _response(<String, Object?>{'expense': <String, Object?>{}});
      }),
    );
    final task = _task(11)
      ..payloadJson = jsonEncode(<String, Object?>{
        ...jsonDecode(_task(11).payloadJson)! as Map<String, dynamic>,
        'sync_payload': <String, Object?>{
          'title': 'Market',
          'total_amount_in_minor': 12500,
          'currency': 'TRY',
          'split': <String, Object?>{
            'type': 'percentage',
            'shares': <Object?>[
              <String, Object?>{
                'user_id': '91000000-0000-4000-8000-000000000001',
                'percentage_basis_points': 3333,
              },
              <String, Object?>{
                'user_id': '91000000-0000-4000-8000-000000000002',
                'percentage_basis_points': 6667,
              },
            ],
          },
        },
      });

    final result = await gateway.push(task);

    expect(result.status, GroupPushStatus.accepted);
    expect(captured.path, '/api/v1/sync/groups/push');
    expect(captured.headers['Idempotency-Key'], task.clientTaskId);
    final split =
        ((captured.data as Map)['sync_payload'] as Map)['split'] as Map;
    expect((split['shares'] as List).last['percentage_basis_points'], 6667);
  });

  test(
    'Dio gateway settlement DTOsunu gereksiz yerel alanlardan arındırır',
    () async {
      late RequestOptions captured;
      final gateway = DioGroupPushGateway(
        _dio((options) {
          captured = options;
          return _response(<String, Object?>{
            'settlement': <String, Object?>{},
          });
        }),
      );
      final task = _settlementTask();

      await gateway.push(task);

      expect(captured.path, '/api/v1/sync/groups/push');
      expect(captured.headers['Idempotency-Key'], task.clientTaskId);
      final syncPayload = (captured.data as Map)['sync_payload'] as Map;
      expect(syncPayload, isNot(contains('id')));
      expect(syncPayload, isNot(contains('group_id')));
      expect(syncPayload, isNot(contains('created_at')));
      expect(syncPayload['amount_in_minor'], 4500);
    },
  );

  test(
    'Dio gateway ExpenseShare create update delete operasyonlarını gönderir',
    () async {
      final captured = <RequestOptions>[];
      final gateway = DioGroupPushGateway(
        _dio((options) {
          captured.add(options);
          return _response(<String, Object?>{
            'operation_id': (options.data as Map)['client_record_id'],
            'status': 'accepted',
          });
        }),
      );

      for (final type in <OfflineTaskType>[
        OfflineTaskType.expenseShareCreate,
        OfflineTaskType.expenseShareUpdate,
        OfflineTaskType.expenseShareDelete,
      ]) {
        final task = _shareTask(type);
        expect((await gateway.push(task)).status, GroupPushStatus.accepted);
      }

      expect(captured, hasLength(3));
      expect(
        captured.map((request) => (request.data as Map)['operation_type']),
        <String>[
          'expenseShareCreate',
          'expenseShareUpdate',
          'expenseShareDelete',
        ],
      );
      expect(
        captured.map((request) => request.headers['Idempotency-Key']).toSet(),
        hasLength(3),
      );
    },
  );

  test(
    'Dio gateway GroupExpense update ve delete operasyonlarını gönderir',
    () async {
      final captured = <RequestOptions>[];
      final gateway = DioGroupPushGateway(
        _dio((options) {
          captured.add(options);
          return _response(<String, Object?>{
            'operation_id': (options.data as Map)['client_record_id'],
            'status': 'accepted',
          });
        }),
      );

      for (final type in <OfflineTaskType>[
        OfflineTaskType.groupExpenseUpdate,
        OfflineTaskType.groupExpenseDelete,
      ]) {
        final task = _expenseMutationTask(type);
        expect((await gateway.push(task)).status, GroupPushStatus.accepted);
      }

      expect(
        captured.map((request) => (request.data as Map)['operation_type']),
        <String>['groupExpenseUpdate', 'groupExpenseDelete'],
      );
      expect(
        captured.map((request) => request.headers['Idempotency-Key']).toSet(),
        hasLength(2),
      );
    },
  );

  test('replayed response aynı clientRecordId için duplicate olur', () async {
    final gateway = DioGroupPushGateway(
      _dio(
        (_) => _response(
          <String, Object?>{'expense': <String, Object?>{}},
          headers: <String, List<String>>{
            'Idempotency-Replayed': <String>['true'],
          },
        ),
      ),
    );
    final task = _task(12);

    final firstReplay = await gateway.push(task);
    final secondReplay = await gateway.push(task);

    expect(firstReplay.status, GroupPushStatus.duplicate);
    expect(secondReplay.operationId, task.clientTaskId);
  });

  for (final entry in <String, String>{
    'expense_financially_locked': 'finansal olarak kilitlendi',
    'record_soft_deleted': 'sunucuda silinmiş',
    'version_mismatch': 'başka bir cihazda güncellendi',
    'idempotency_conflict': 'işlem kimliği',
  }.entries) {
    test('409 ${entry.key} anlaşılır conflict sonucuna çevrilir', () async {
      final gateway = DioGroupPushGateway(
        _dio(
          (_) => _response(<String, Object?>{
            'detail': <String, Object?>{
              'code': entry.key,
              'message': 'server detail',
            },
          }, statusCode: 409),
        ),
      );

      final result = await gateway.push(_task(13));

      expect(result.status, GroupPushStatus.conflict);
      expect(result.conflictCode, entry.key);
      expect(result.message, contains(entry.value));
    });
  }

  test('bilinmeyen 409 kodunda ham sunucu mesajını kullanmaz', () async {
    const rawServerMessage =
        'PostgreSQL connection failed at postgres://admin@example.test/db';
    final gateway = DioGroupPushGateway(
      _dio(
        (_) => _response(<String, Object?>{
          'detail': <String, Object?>{
            'code': 'unknown_conflict',
            'message': rawServerMessage,
          },
        }, statusCode: 409),
      ),
    );

    final result = await gateway.push(_task(14));

    expect(result.status, GroupPushStatus.conflict);
    expect(result.conflictCode, 'unknown_conflict');
    expect(result.message, 'Finansal kayıt sunucudaki sürümle çakıştı.');
    expect(result.message, isNot(contains(rawServerMessage)));
    expect(result.message, isNot(contains('postgres://')));
  });
}

OfflineTask _task(int id, {String title = 'Market'}) {
  final clientRecordId =
      '93000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  return OfflineTask()
    ..id = id
    ..clientTaskId = clientRecordId
    ..type = OfflineTaskType.groupExpenseCreate
    ..status = OfflineTaskStatus.pending
    ..payloadJson = jsonEncode(<String, Object?>{
      'operation_type': OfflineTaskType.groupExpenseCreate.name,
      'group_id': '92000000-0000-4000-8000-000000000001',
      'client_record_id': clientRecordId,
      'owner_key': 'user:91000000-0000-4000-8000-000000000001',
      'sync_state': SyncState.pending.name,
      'payload': <String, Object?>{
        'id': '94000000-0000-4000-8000-${id.toString().padLeft(12, '0')}',
        'title': title,
      },
    })
    ..createdAt = DateTime.utc(2026, 8, 17)
    ..updatedAt = DateTime.utc(2026, 8, 17);
}

OfflineTask _settlementTask() {
  const id = '95000000-0000-4000-8000-000000000001';
  return OfflineTask()
    ..clientTaskId = id
    ..type = OfflineTaskType.settlementCreate
    ..status = OfflineTaskStatus.pending
    ..payloadJson = jsonEncode(<String, Object?>{
      'operation_type': OfflineTaskType.settlementCreate.name,
      'group_id': '92000000-0000-4000-8000-000000000001',
      'client_record_id': id,
      'owner_key': 'user:91000000-0000-4000-8000-000000000001',
      'sync_state': SyncState.pending.name,
      'payload': <String, Object?>{
        'id': id,
        'group_id': '92000000-0000-4000-8000-000000000001',
        'from_user_id': '91000000-0000-4000-8000-000000000001',
        'to_user_id': '91000000-0000-4000-8000-000000000002',
        'amount_in_minor': 4500,
        'currency': 'TRY',
        'settled_at': '2026-08-17T12:00:00Z',
        'note': null,
        'created_at': '2026-08-17T12:00:00Z',
      },
    })
    ..createdAt = DateTime.utc(2026, 8, 17)
    ..updatedAt = DateTime.utc(2026, 8, 17);
}

OfflineTask _shareTask(OfflineTaskType type) {
  final suffix = switch (type) {
    OfflineTaskType.expenseShareCreate => '1',
    OfflineTaskType.expenseShareUpdate => '2',
    OfflineTaskType.expenseShareDelete => '3',
    _ => throw ArgumentError.value(type),
  };
  final id = '96000000-0000-4000-8000-${suffix.padLeft(12, '0')}';
  return OfflineTask()
    ..clientTaskId = id
    ..type = type
    ..status = OfflineTaskStatus.pending
    ..payloadJson = jsonEncode(<String, Object?>{
      'operation_type': type.name,
      'group_id': '92000000-0000-4000-8000-000000000001',
      'client_record_id': id,
      'owner_key': 'user:91000000-0000-4000-8000-000000000001',
      'sync_state': type == OfflineTaskType.expenseShareDelete
          ? SyncState.pendingDelete.name
          : SyncState.pending.name,
      'payload': <String, Object?>{
        'expense_id': '94000000-0000-4000-8000-000000000001',
        'user_id': '91000000-0000-4000-8000-000000000002',
        if (type != OfflineTaskType.expenseShareDelete) ...<String, Object?>{
          'display_name': 'Pay sahibi',
          'amount_in_minor': 4500,
          'status': 'open',
          'settled_at': null,
        },
      },
    })
    ..createdAt = DateTime.utc(2026, 8, 17)
    ..updatedAt = DateTime.utc(2026, 8, 17);
}

OfflineTask _expenseMutationTask(OfflineTaskType type) {
  final suffix = switch (type) {
    OfflineTaskType.groupExpenseUpdate => '1',
    OfflineTaskType.groupExpenseDelete => '2',
    _ => throw ArgumentError.value(type),
  };
  final id = '97000000-0000-4000-8000-${suffix.padLeft(12, '0')}';
  const expenseId = '94000000-0000-4000-8000-000000000001';
  const groupId = '92000000-0000-4000-8000-000000000001';
  return OfflineTask()
    ..clientTaskId = id
    ..type = type
    ..status = OfflineTaskStatus.pending
    ..payloadJson = jsonEncode(<String, Object?>{
      'operation_type': type.name,
      'group_id': groupId,
      'client_record_id': id,
      'owner_key': 'user:91000000-0000-4000-8000-000000000001',
      'sync_state': type == OfflineTaskType.groupExpenseDelete
          ? SyncState.pendingDelete.name
          : SyncState.pending.name,
      'payload': <String, Object?>{
        'group_id': groupId,
        if (type == OfflineTaskType.groupExpenseDelete)
          'expense_id': expenseId
        else ...<String, Object?>{
          'id': expenseId,
          'payer_user_id': '91000000-0000-4000-8000-000000000001',
          'title': 'Güncellenen masraf',
          'expense_date': '2026-08-17T12:00:00Z',
          'total_amount_in_minor': 4500,
          'currency': 'TRY',
          'split_type': 'fixed_amount',
          'shares': <Object?>[],
        },
      },
    })
    ..createdAt = DateTime.utc(2026, 8, 17)
    ..updatedAt = DateTime.utc(2026, 8, 17);
}

Dio _dio(ResponseBody Function(RequestOptions) handler) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _Adapter(handler);

ResponseBody _response(
  Map<String, Object?> body, {
  int statusCode = 200,
  Map<String, List<String>> headers = const <String, List<String>>{},
}) => ResponseBody.fromString(
  jsonEncode(body),
  statusCode,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    ...headers,
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);

  @override
  void close({bool force = false}) {}
}
