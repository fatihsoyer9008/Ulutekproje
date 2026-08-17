// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_expense_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetGroupExpenseEntityCollection on Isar {
  IsarCollection<GroupExpenseEntity> get groupExpenseEntitys =>
      this.collection();
}

const GroupExpenseEntitySchema = CollectionSchema(
  name: r'GroupExpenseEntity',
  id: -7549672518347652723,
  properties: {
    r'clientRecordId': PropertySchema(
      id: 0,
      name: r'clientRecordId',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'createdBy': PropertySchema(
      id: 2,
      name: r'createdBy',
      type: IsarType.string,
    ),
    r'currency': PropertySchema(
      id: 3,
      name: r'currency',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 4,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'expenseDate': PropertySchema(
      id: 5,
      name: r'expenseDate',
      type: IsarType.dateTime,
    ),
    r'expenseId': PropertySchema(
      id: 6,
      name: r'expenseId',
      type: IsarType.string,
    ),
    r'groupId': PropertySchema(
      id: 7,
      name: r'groupId',
      type: IsarType.string,
    ),
    r'isFinanciallyLocked': PropertySchema(
      id: 8,
      name: r'isFinanciallyLocked',
      type: IsarType.bool,
    ),
    r'note': PropertySchema(
      id: 9,
      name: r'note',
      type: IsarType.string,
    ),
    r'ownerKey': PropertySchema(
      id: 10,
      name: r'ownerKey',
      type: IsarType.string,
    ),
    r'payerUserId': PropertySchema(
      id: 11,
      name: r'payerUserId',
      type: IsarType.string,
    ),
    r'payloadJson': PropertySchema(
      id: 12,
      name: r'payloadJson',
      type: IsarType.string,
    ),
    r'receiptId': PropertySchema(
      id: 13,
      name: r'receiptId',
      type: IsarType.string,
    ),
    r'splitType': PropertySchema(
      id: 14,
      name: r'splitType',
      type: IsarType.string,
    ),
    r'syncState': PropertySchema(
      id: 15,
      name: r'syncState',
      type: IsarType.string,
      enumMap: _GroupExpenseEntitysyncStateEnumValueMap,
    ),
    r'title': PropertySchema(
      id: 16,
      name: r'title',
      type: IsarType.string,
    ),
    r'totalAmountInMinor': PropertySchema(
      id: 17,
      name: r'totalAmountInMinor',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 18,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _groupExpenseEntityEstimateSize,
  serialize: _groupExpenseEntitySerialize,
  deserialize: _groupExpenseEntityDeserialize,
  deserializeProp: _groupExpenseEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'expenseId': IndexSchema(
      id: -8289172275633362361,
      name: r'expenseId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'expenseId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'groupId': IndexSchema(
      id: -8523216633229774932,
      name: r'groupId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'groupId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'clientRecordId': IndexSchema(
      id: 5009501472071969908,
      name: r'clientRecordId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'clientRecordId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'ownerKey': IndexSchema(
      id: -688544438286220026,
      name: r'ownerKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'ownerKey',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _groupExpenseEntityGetId,
  getLinks: _groupExpenseEntityGetLinks,
  attach: _groupExpenseEntityAttach,
  version: '3.1.0+1',
);

int _groupExpenseEntityEstimateSize(
  GroupExpenseEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.clientRecordId.length * 3;
  {
    final value = object.createdBy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.currency.length * 3;
  bytesCount += 3 + object.expenseId.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerKey.length * 3;
  bytesCount += 3 + object.payerUserId.length * 3;
  bytesCount += 3 + object.payloadJson.length * 3;
  {
    final value = object.receiptId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.splitType.length * 3;
  bytesCount += 3 + object.syncState.name.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _groupExpenseEntitySerialize(
  GroupExpenseEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.clientRecordId);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.createdBy);
  writer.writeString(offsets[3], object.currency);
  writer.writeDateTime(offsets[4], object.deletedAt);
  writer.writeDateTime(offsets[5], object.expenseDate);
  writer.writeString(offsets[6], object.expenseId);
  writer.writeString(offsets[7], object.groupId);
  writer.writeBool(offsets[8], object.isFinanciallyLocked);
  writer.writeString(offsets[9], object.note);
  writer.writeString(offsets[10], object.ownerKey);
  writer.writeString(offsets[11], object.payerUserId);
  writer.writeString(offsets[12], object.payloadJson);
  writer.writeString(offsets[13], object.receiptId);
  writer.writeString(offsets[14], object.splitType);
  writer.writeString(offsets[15], object.syncState.name);
  writer.writeString(offsets[16], object.title);
  writer.writeLong(offsets[17], object.totalAmountInMinor);
  writer.writeDateTime(offsets[18], object.updatedAt);
}

GroupExpenseEntity _groupExpenseEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = GroupExpenseEntity();
  object.clientRecordId = reader.readString(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.createdBy = reader.readStringOrNull(offsets[2]);
  object.currency = reader.readString(offsets[3]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[4]);
  object.expenseDate = reader.readDateTime(offsets[5]);
  object.expenseId = reader.readString(offsets[6]);
  object.groupId = reader.readString(offsets[7]);
  object.id = id;
  object.isFinanciallyLocked = reader.readBool(offsets[8]);
  object.note = reader.readStringOrNull(offsets[9]);
  object.ownerKey = reader.readString(offsets[10]);
  object.payerUserId = reader.readString(offsets[11]);
  object.payloadJson = reader.readString(offsets[12]);
  object.receiptId = reader.readStringOrNull(offsets[13]);
  object.splitType = reader.readString(offsets[14]);
  object.syncState = _GroupExpenseEntitysyncStateValueEnumMap[
          reader.readStringOrNull(offsets[15])] ??
      SyncState.localOnly;
  object.title = reader.readString(offsets[16]);
  object.totalAmountInMinor = reader.readLong(offsets[17]);
  object.updatedAt = reader.readDateTime(offsets[18]);
  return object;
}

P _groupExpenseEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readDateTime(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    case 9:
      return (reader.readStringOrNull(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    case 15:
      return (_GroupExpenseEntitysyncStateValueEnumMap[
              reader.readStringOrNull(offset)] ??
          SyncState.localOnly) as P;
    case 16:
      return (reader.readString(offset)) as P;
    case 17:
      return (reader.readLong(offset)) as P;
    case 18:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _GroupExpenseEntitysyncStateEnumValueMap = {
  r'localOnly': r'localOnly',
  r'pending': r'pending',
  r'synced': r'synced',
  r'failed': r'failed',
  r'pendingDelete': r'pendingDelete',
};
const _GroupExpenseEntitysyncStateValueEnumMap = {
  r'localOnly': SyncState.localOnly,
  r'pending': SyncState.pending,
  r'synced': SyncState.synced,
  r'failed': SyncState.failed,
  r'pendingDelete': SyncState.pendingDelete,
};

Id _groupExpenseEntityGetId(GroupExpenseEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _groupExpenseEntityGetLinks(
    GroupExpenseEntity object) {
  return [];
}

void _groupExpenseEntityAttach(
    IsarCollection<dynamic> col, Id id, GroupExpenseEntity object) {
  object.id = id;
}

extension GroupExpenseEntityByIndex on IsarCollection<GroupExpenseEntity> {
  Future<GroupExpenseEntity?> getByExpenseId(String expenseId) {
    return getByIndex(r'expenseId', [expenseId]);
  }

  GroupExpenseEntity? getByExpenseIdSync(String expenseId) {
    return getByIndexSync(r'expenseId', [expenseId]);
  }

  Future<bool> deleteByExpenseId(String expenseId) {
    return deleteByIndex(r'expenseId', [expenseId]);
  }

  bool deleteByExpenseIdSync(String expenseId) {
    return deleteByIndexSync(r'expenseId', [expenseId]);
  }

  Future<List<GroupExpenseEntity?>> getAllByExpenseId(
      List<String> expenseIdValues) {
    final values = expenseIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'expenseId', values);
  }

  List<GroupExpenseEntity?> getAllByExpenseIdSync(
      List<String> expenseIdValues) {
    final values = expenseIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'expenseId', values);
  }

  Future<int> deleteAllByExpenseId(List<String> expenseIdValues) {
    final values = expenseIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'expenseId', values);
  }

  int deleteAllByExpenseIdSync(List<String> expenseIdValues) {
    final values = expenseIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'expenseId', values);
  }

  Future<Id> putByExpenseId(GroupExpenseEntity object) {
    return putByIndex(r'expenseId', object);
  }

  Id putByExpenseIdSync(GroupExpenseEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'expenseId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByExpenseId(List<GroupExpenseEntity> objects) {
    return putAllByIndex(r'expenseId', objects);
  }

  List<Id> putAllByExpenseIdSync(List<GroupExpenseEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'expenseId', objects, saveLinks: saveLinks);
  }

  Future<GroupExpenseEntity?> getByClientRecordId(String clientRecordId) {
    return getByIndex(r'clientRecordId', [clientRecordId]);
  }

  GroupExpenseEntity? getByClientRecordIdSync(String clientRecordId) {
    return getByIndexSync(r'clientRecordId', [clientRecordId]);
  }

  Future<bool> deleteByClientRecordId(String clientRecordId) {
    return deleteByIndex(r'clientRecordId', [clientRecordId]);
  }

  bool deleteByClientRecordIdSync(String clientRecordId) {
    return deleteByIndexSync(r'clientRecordId', [clientRecordId]);
  }

  Future<List<GroupExpenseEntity?>> getAllByClientRecordId(
      List<String> clientRecordIdValues) {
    final values = clientRecordIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'clientRecordId', values);
  }

  List<GroupExpenseEntity?> getAllByClientRecordIdSync(
      List<String> clientRecordIdValues) {
    final values = clientRecordIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'clientRecordId', values);
  }

  Future<int> deleteAllByClientRecordId(List<String> clientRecordIdValues) {
    final values = clientRecordIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'clientRecordId', values);
  }

  int deleteAllByClientRecordIdSync(List<String> clientRecordIdValues) {
    final values = clientRecordIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'clientRecordId', values);
  }

  Future<Id> putByClientRecordId(GroupExpenseEntity object) {
    return putByIndex(r'clientRecordId', object);
  }

  Id putByClientRecordIdSync(GroupExpenseEntity object,
      {bool saveLinks = true}) {
    return putByIndexSync(r'clientRecordId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByClientRecordId(List<GroupExpenseEntity> objects) {
    return putAllByIndex(r'clientRecordId', objects);
  }

  List<Id> putAllByClientRecordIdSync(List<GroupExpenseEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'clientRecordId', objects, saveLinks: saveLinks);
  }
}

extension GroupExpenseEntityQueryWhereSort
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QWhere> {
  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension GroupExpenseEntityQueryWhere
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QWhereClause> {
  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      expenseIdEqualTo(String expenseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'expenseId',
        value: [expenseId],
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      expenseIdNotEqualTo(String expenseId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expenseId',
              lower: [],
              upper: [expenseId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expenseId',
              lower: [expenseId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expenseId',
              lower: [expenseId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'expenseId',
              lower: [],
              upper: [expenseId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'groupId',
        value: [groupId],
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      groupIdNotEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [groupId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'groupId',
              lower: [],
              upper: [groupId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      clientRecordIdEqualTo(String clientRecordId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'clientRecordId',
        value: [clientRecordId],
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      clientRecordIdNotEqualTo(String clientRecordId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'clientRecordId',
              lower: [],
              upper: [clientRecordId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'clientRecordId',
              lower: [clientRecordId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'clientRecordId',
              lower: [clientRecordId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'clientRecordId',
              lower: [],
              upper: [clientRecordId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      ownerKeyEqualTo(String ownerKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerKey',
        value: [ownerKey],
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterWhereClause>
      ownerKeyNotEqualTo(String ownerKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerKey',
              lower: [],
              upper: [ownerKey],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerKey',
              lower: [ownerKey],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerKey',
              lower: [ownerKey],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'ownerKey',
              lower: [],
              upper: [ownerKey],
              includeUpper: false,
            ));
      }
    });
  }
}

extension GroupExpenseEntityQueryFilter
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QFilterCondition> {
  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientRecordId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'clientRecordId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'clientRecordId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'clientRecordId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'clientRecordId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'clientRecordId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'clientRecordId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'clientRecordId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'clientRecordId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      clientRecordIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'clientRecordId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'createdBy',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'createdBy',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'createdBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'createdBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'createdBy',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'createdBy',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdBy',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      createdByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'createdBy',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'currency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'currency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'currency',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'currency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'currency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'currency',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'currency',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currency',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      currencyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'currency',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      deletedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      deletedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseDateEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expenseDate',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseDateGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expenseDate',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseDateLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expenseDate',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseDateBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expenseDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expenseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'expenseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'expenseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'expenseId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'expenseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'expenseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'expenseId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'expenseId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'expenseId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      expenseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'expenseId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      isFinanciallyLockedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isFinanciallyLocked',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'note',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'note',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'note',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'note',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'note',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'ownerKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'ownerKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'ownerKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'ownerKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'ownerKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerKey',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      ownerKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerKey',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payerUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'payerUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'payerUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'payerUserId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'payerUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'payerUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'payerUserId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'payerUserId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payerUserId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payerUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'payerUserId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'payloadJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'payloadJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'payloadJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payloadJson',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'payloadJson',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'receiptId',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'receiptId',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'receiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'receiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'receiptId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'receiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'receiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'receiptId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'receiptId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'receiptId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      receiptIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'receiptId',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'splitType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'splitType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'splitType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'splitType',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'splitType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'splitType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'splitType',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'splitType',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'splitType',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      splitTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'splitType',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateEqualTo(
    SyncState value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateGreaterThan(
    SyncState value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'syncState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateLessThan(
    SyncState value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'syncState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateBetween(
    SyncState lower,
    SyncState upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'syncState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'syncState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'syncState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'syncState',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'syncState',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'syncState',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      syncStateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'syncState',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      totalAmountInMinorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'totalAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      totalAmountInMinorGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'totalAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      totalAmountInMinorLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'totalAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      totalAmountInMinorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'totalAmountInMinor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension GroupExpenseEntityQueryObject
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QFilterCondition> {}

extension GroupExpenseEntityQueryLinks
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QFilterCondition> {}

extension GroupExpenseEntityQuerySortBy
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QSortBy> {
  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByClientRecordId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientRecordId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByClientRecordIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientRecordId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByCreatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByCreatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByCurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByCurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByExpenseDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseDate', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByExpenseDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseDate', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByExpenseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByExpenseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByIsFinanciallyLocked() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFinanciallyLocked', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByIsFinanciallyLockedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFinanciallyLocked', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByPayerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payerUserId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByPayerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payerUserId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortBySplitType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitType', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortBySplitTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitType', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByTotalAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension GroupExpenseEntityQuerySortThenBy
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QSortThenBy> {
  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByClientRecordId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientRecordId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByClientRecordIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clientRecordId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByCreatedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByCreatedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdBy', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByCurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByCurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByExpenseDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseDate', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByExpenseDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseDate', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByExpenseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByExpenseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByIsFinanciallyLocked() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFinanciallyLocked', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByIsFinanciallyLockedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFinanciallyLocked', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByPayerUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payerUserId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByPayerUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payerUserId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenBySplitType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitType', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenBySplitTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'splitType', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenBySyncState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenBySyncStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'syncState', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByTotalAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension GroupExpenseEntityQueryWhereDistinct
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct> {
  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByClientRecordId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clientRecordId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByCreatedBy({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByCurrency({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'currency', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByExpenseDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expenseDate');
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByExpenseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expenseId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByIsFinanciallyLocked() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFinanciallyLocked');
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByOwnerKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByPayerUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payerUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByReceiptId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiptId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctBySplitType({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'splitType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctBySyncState({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'syncState', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalAmountInMinor');
    });
  }

  QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension GroupExpenseEntityQueryProperty
    on QueryBuilder<GroupExpenseEntity, GroupExpenseEntity, QQueryProperty> {
  QueryBuilder<GroupExpenseEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations>
      clientRecordIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clientRecordId');
    });
  }

  QueryBuilder<GroupExpenseEntity, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<GroupExpenseEntity, String?, QQueryOperations>
      createdByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdBy');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations>
      currencyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currency');
    });
  }

  QueryBuilder<GroupExpenseEntity, DateTime?, QQueryOperations>
      deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<GroupExpenseEntity, DateTime, QQueryOperations>
      expenseDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expenseDate');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations>
      expenseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expenseId');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<GroupExpenseEntity, bool, QQueryOperations>
      isFinanciallyLockedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFinanciallyLocked');
    });
  }

  QueryBuilder<GroupExpenseEntity, String?, QQueryOperations> noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations>
      ownerKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerKey');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations>
      payerUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payerUserId');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations>
      payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }

  QueryBuilder<GroupExpenseEntity, String?, QQueryOperations>
      receiptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiptId');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations>
      splitTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'splitType');
    });
  }

  QueryBuilder<GroupExpenseEntity, SyncState, QQueryOperations>
      syncStateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'syncState');
    });
  }

  QueryBuilder<GroupExpenseEntity, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<GroupExpenseEntity, int, QQueryOperations>
      totalAmountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalAmountInMinor');
    });
  }

  QueryBuilder<GroupExpenseEntity, DateTime, QQueryOperations>
      updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
