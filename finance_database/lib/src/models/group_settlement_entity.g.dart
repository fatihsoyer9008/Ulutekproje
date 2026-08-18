// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_settlement_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetGroupSettlementEntityCollection on Isar {
  IsarCollection<GroupSettlementEntity> get groupSettlementEntitys =>
      this.collection();
}

const GroupSettlementEntitySchema = CollectionSchema(
  name: r'GroupSettlementEntity',
  id: 5487039980106979957,
  properties: {
    r'amountInMinor': PropertySchema(
      id: 0,
      name: r'amountInMinor',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'currency': PropertySchema(
      id: 2,
      name: r'currency',
      type: IsarType.string,
    ),
    r'fromUserId': PropertySchema(
      id: 3,
      name: r'fromUserId',
      type: IsarType.string,
    ),
    r'groupId': PropertySchema(id: 4, name: r'groupId', type: IsarType.string),
    r'note': PropertySchema(id: 5, name: r'note', type: IsarType.string),
    r'ownerKey': PropertySchema(
      id: 6,
      name: r'ownerKey',
      type: IsarType.string,
    ),
    r'payloadJson': PropertySchema(
      id: 7,
      name: r'payloadJson',
      type: IsarType.string,
    ),
    r'recordKey': PropertySchema(
      id: 8,
      name: r'recordKey',
      type: IsarType.string,
    ),
    r'serverUpdatedAt': PropertySchema(
      id: 9,
      name: r'serverUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'settledAt': PropertySchema(
      id: 10,
      name: r'settledAt',
      type: IsarType.dateTime,
    ),
    r'settlementId': PropertySchema(
      id: 11,
      name: r'settlementId',
      type: IsarType.string,
    ),
    r'toUserId': PropertySchema(
      id: 12,
      name: r'toUserId',
      type: IsarType.string,
    ),
  },
  estimateSize: _groupSettlementEntityEstimateSize,
  serialize: _groupSettlementEntitySerialize,
  deserialize: _groupSettlementEntityDeserialize,
  deserializeProp: _groupSettlementEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'recordKey': IndexSchema(
      id: -1694304532238354687,
      name: r'recordKey',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'recordKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'settlementId': IndexSchema(
      id: -6820445565808363421,
      name: r'settlementId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'settlementId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
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
        ),
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
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _groupSettlementEntityGetId,
  getLinks: _groupSettlementEntityGetLinks,
  attach: _groupSettlementEntityAttach,
  version: '3.1.0+1',
);

int _groupSettlementEntityEstimateSize(
  GroupSettlementEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.currency.length * 3;
  bytesCount += 3 + object.fromUserId.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  {
    final value = object.note;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerKey.length * 3;
  bytesCount += 3 + object.payloadJson.length * 3;
  bytesCount += 3 + object.recordKey.length * 3;
  bytesCount += 3 + object.settlementId.length * 3;
  bytesCount += 3 + object.toUserId.length * 3;
  return bytesCount;
}

void _groupSettlementEntitySerialize(
  GroupSettlementEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.amountInMinor);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.currency);
  writer.writeString(offsets[3], object.fromUserId);
  writer.writeString(offsets[4], object.groupId);
  writer.writeString(offsets[5], object.note);
  writer.writeString(offsets[6], object.ownerKey);
  writer.writeString(offsets[7], object.payloadJson);
  writer.writeString(offsets[8], object.recordKey);
  writer.writeDateTime(offsets[9], object.serverUpdatedAt);
  writer.writeDateTime(offsets[10], object.settledAt);
  writer.writeString(offsets[11], object.settlementId);
  writer.writeString(offsets[12], object.toUserId);
}

GroupSettlementEntity _groupSettlementEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = GroupSettlementEntity();
  object.amountInMinor = reader.readLong(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.currency = reader.readString(offsets[2]);
  object.fromUserId = reader.readString(offsets[3]);
  object.groupId = reader.readString(offsets[4]);
  object.id = id;
  object.note = reader.readStringOrNull(offsets[5]);
  object.ownerKey = reader.readString(offsets[6]);
  object.payloadJson = reader.readString(offsets[7]);
  object.recordKey = reader.readString(offsets[8]);
  object.serverUpdatedAt = reader.readDateTime(offsets[9]);
  object.settledAt = reader.readDateTime(offsets[10]);
  object.settlementId = reader.readString(offsets[11]);
  object.toUserId = reader.readString(offsets[12]);
  return object;
}

P _groupSettlementEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _groupSettlementEntityGetId(GroupSettlementEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _groupSettlementEntityGetLinks(
  GroupSettlementEntity object,
) {
  return [];
}

void _groupSettlementEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  GroupSettlementEntity object,
) {
  object.id = id;
}

extension GroupSettlementEntityByIndex
    on IsarCollection<GroupSettlementEntity> {
  Future<GroupSettlementEntity?> getByRecordKey(String recordKey) {
    return getByIndex(r'recordKey', [recordKey]);
  }

  GroupSettlementEntity? getByRecordKeySync(String recordKey) {
    return getByIndexSync(r'recordKey', [recordKey]);
  }

  Future<bool> deleteByRecordKey(String recordKey) {
    return deleteByIndex(r'recordKey', [recordKey]);
  }

  bool deleteByRecordKeySync(String recordKey) {
    return deleteByIndexSync(r'recordKey', [recordKey]);
  }

  Future<List<GroupSettlementEntity?>> getAllByRecordKey(
    List<String> recordKeyValues,
  ) {
    final values = recordKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'recordKey', values);
  }

  List<GroupSettlementEntity?> getAllByRecordKeySync(
    List<String> recordKeyValues,
  ) {
    final values = recordKeyValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'recordKey', values);
  }

  Future<int> deleteAllByRecordKey(List<String> recordKeyValues) {
    final values = recordKeyValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'recordKey', values);
  }

  int deleteAllByRecordKeySync(List<String> recordKeyValues) {
    final values = recordKeyValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'recordKey', values);
  }

  Future<Id> putByRecordKey(GroupSettlementEntity object) {
    return putByIndex(r'recordKey', object);
  }

  Id putByRecordKeySync(GroupSettlementEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'recordKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByRecordKey(List<GroupSettlementEntity> objects) {
    return putAllByIndex(r'recordKey', objects);
  }

  List<Id> putAllByRecordKeySync(
    List<GroupSettlementEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'recordKey', objects, saveLinks: saveLinks);
  }
}

extension GroupSettlementEntityQueryWhereSort
    on QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QWhere> {
  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension GroupSettlementEntityQueryWhere
    on
        QueryBuilder<
          GroupSettlementEntity,
          GroupSettlementEntity,
          QWhereClause
        > {
  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
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

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  recordKeyEqualTo(String recordKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'recordKey', value: [recordKey]),
      );
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  recordKeyNotEqualTo(String recordKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordKey',
                lower: [],
                upper: [recordKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordKey',
                lower: [recordKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordKey',
                lower: [recordKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'recordKey',
                lower: [],
                upper: [recordKey],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  settlementIdEqualTo(String settlementId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'settlementId',
          value: [settlementId],
        ),
      );
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  settlementIdNotEqualTo(String settlementId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'settlementId',
                lower: [],
                upper: [settlementId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'settlementId',
                lower: [settlementId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'settlementId',
                lower: [settlementId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'settlementId',
                lower: [],
                upper: [settlementId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'groupId', value: [groupId]),
      );
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  groupIdNotEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [groupId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'groupId',
                lower: [],
                upper: [groupId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  ownerKeyEqualTo(String ownerKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'ownerKey', value: [ownerKey]),
      );
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterWhereClause>
  ownerKeyNotEqualTo(String ownerKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerKey',
                lower: [],
                upper: [ownerKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerKey',
                lower: [ownerKey],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerKey',
                lower: [ownerKey],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'ownerKey',
                lower: [],
                upper: [ownerKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension GroupSettlementEntityQueryFilter
    on
        QueryBuilder<
          GroupSettlementEntity,
          GroupSettlementEntity,
          QFilterCondition
        > {
  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  amountInMinorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'amountInMinor', value: value),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  amountInMinorGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'amountInMinor',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  amountInMinorLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'amountInMinor',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  amountInMinorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'amountInMinor',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'currency',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'currency',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'currency',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'currency',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'currency',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'currency',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'currency',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'currency',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'currency', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  currencyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'currency', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fromUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fromUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fromUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fromUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'fromUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'fromUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'fromUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'fromUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fromUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  fromUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fromUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'groupId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'groupId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'groupId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'groupId', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'groupId', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'note'),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'note'),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'note',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'note',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'note',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  noteIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'note', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ownerKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ownerKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ownerKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ownerKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ownerKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ownerKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ownerKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ownerKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerKey', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  ownerKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerKey', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'payloadJson',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'payloadJson',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'payloadJson',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'recordKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'recordKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'recordKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'recordKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'recordKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'recordKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'recordKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'recordKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recordKey', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  recordKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'recordKey', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  serverUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'serverUpdatedAt', value: value),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  serverUpdatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'serverUpdatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  serverUpdatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'serverUpdatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  serverUpdatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'serverUpdatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settledAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'settledAt', value: value),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settledAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'settledAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settledAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'settledAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settledAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'settledAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'settlementId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'settlementId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'settlementId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'settlementId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'settlementId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'settlementId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'settlementId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'settlementId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'settlementId', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  settlementIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'settlementId', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'toUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'toUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'toUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'toUserId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'toUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'toUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'toUserId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'toUserId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'toUserId', value: ''),
      );
    });
  }

  QueryBuilder<
    GroupSettlementEntity,
    GroupSettlementEntity,
    QAfterFilterCondition
  >
  toUserIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'toUserId', value: ''),
      );
    });
  }
}

extension GroupSettlementEntityQueryObject
    on
        QueryBuilder<
          GroupSettlementEntity,
          GroupSettlementEntity,
          QFilterCondition
        > {}

extension GroupSettlementEntityQueryLinks
    on
        QueryBuilder<
          GroupSettlementEntity,
          GroupSettlementEntity,
          QFilterCondition
        > {}

extension GroupSettlementEntityQuerySortBy
    on QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QSortBy> {
  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByCurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByCurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByFromUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUserId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByFromUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUserId', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByRecordKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByRecordKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByServerUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortBySettledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortBySettledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortBySettlementId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settlementId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortBySettlementIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settlementId', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByToUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUserId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  sortByToUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUserId', Sort.desc);
    });
  }
}

extension GroupSettlementEntityQuerySortThenBy
    on QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QSortThenBy> {
  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByCurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByCurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByFromUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUserId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByFromUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUserId', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByNote() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByNoteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'note', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByRecordKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByRecordKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByServerUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenBySettledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenBySettledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenBySettlementId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settlementId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenBySettlementIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settlementId', Sort.desc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByToUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUserId', Sort.asc);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QAfterSortBy>
  thenByToUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUserId', Sort.desc);
    });
  }
}

extension GroupSettlementEntityQueryWhereDistinct
    on QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct> {
  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amountInMinor');
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByCurrency({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'currency', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByFromUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromUserId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByNote({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'note', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByOwnerKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByRecordKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recordKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverUpdatedAt');
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctBySettledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'settledAt');
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctBySettlementId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'settlementId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<GroupSettlementEntity, GroupSettlementEntity, QDistinct>
  distinctByToUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toUserId', caseSensitive: caseSensitive);
    });
  }
}

extension GroupSettlementEntityQueryProperty
    on
        QueryBuilder<
          GroupSettlementEntity,
          GroupSettlementEntity,
          QQueryProperty
        > {
  QueryBuilder<GroupSettlementEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<GroupSettlementEntity, int, QQueryOperations>
  amountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amountInMinor');
    });
  }

  QueryBuilder<GroupSettlementEntity, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  currencyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currency');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  fromUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromUserId');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<GroupSettlementEntity, String?, QQueryOperations>
  noteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'note');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  ownerKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerKey');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  recordKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recordKey');
    });
  }

  QueryBuilder<GroupSettlementEntity, DateTime, QQueryOperations>
  serverUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverUpdatedAt');
    });
  }

  QueryBuilder<GroupSettlementEntity, DateTime, QQueryOperations>
  settledAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'settledAt');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  settlementIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'settlementId');
    });
  }

  QueryBuilder<GroupSettlementEntity, String, QQueryOperations>
  toUserIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toUserId');
    });
  }
}
