import 'dart:convert';

import 'package:app_main/features/groups/data/group_sync_gateway.dart';
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
