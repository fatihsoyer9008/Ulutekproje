// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_share_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetExpenseShareEntityCollection on Isar {
  IsarCollection<ExpenseShareEntity> get expenseShareEntitys =>
      this.collection();
}

const ExpenseShareEntitySchema = CollectionSchema(
  name: r'ExpenseShareEntity',
  id: 294232144748780503,
  properties: {
    r'amountInMinor': PropertySchema(
      id: 0,
      name: r'amountInMinor',
      type: IsarType.long,
    ),
    r'deletedAt': PropertySchema(
      id: 1,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'displayName': PropertySchema(
      id: 2,
      name: r'displayName',
      type: IsarType.string,
    ),
    r'expenseId': PropertySchema(
      id: 3,
      name: r'expenseId',
      type: IsarType.string,
    ),
    r'groupId': PropertySchema(id: 4, name: r'groupId', type: IsarType.string),
    r'ownerKey': PropertySchema(
      id: 5,
      name: r'ownerKey',
      type: IsarType.string,
    ),
    r'payloadJson': PropertySchema(
      id: 6,
      name: r'payloadJson',
      type: IsarType.string,
    ),
    r'recordKey': PropertySchema(
      id: 7,
      name: r'recordKey',
      type: IsarType.string,
    ),
    r'serverUpdatedAt': PropertySchema(
      id: 8,
      name: r'serverUpdatedAt',
      type: IsarType.dateTime,
    ),
    r'settledAt': PropertySchema(
      id: 9,
      name: r'settledAt',
      type: IsarType.dateTime,
    ),
    r'status': PropertySchema(id: 10, name: r'status', type: IsarType.string),
    r'userId': PropertySchema(id: 11, name: r'userId', type: IsarType.string),
  },
  estimateSize: _expenseShareEntityEstimateSize,
  serialize: _expenseShareEntitySerialize,
  deserialize: _expenseShareEntityDeserialize,
  deserializeProp: _expenseShareEntityDeserializeProp,
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
    r'expenseId': IndexSchema(
      id: -8289172275633362361,
      name: r'expenseId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'expenseId',
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
  getId: _expenseShareEntityGetId,
  getLinks: _expenseShareEntityGetLinks,
  attach: _expenseShareEntityAttach,
  version: '3.1.0+1',
);

int _expenseShareEntityEstimateSize(
  ExpenseShareEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.displayName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.expenseId.length * 3;
  bytesCount += 3 + object.groupId.length * 3;
  bytesCount += 3 + object.ownerKey.length * 3;
  {
    final value = object.payloadJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.recordKey.length * 3;
  {
    final value = object.status;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.userId.length * 3;
  return bytesCount;
}

void _expenseShareEntitySerialize(
  ExpenseShareEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.amountInMinor);
  writer.writeDateTime(offsets[1], object.deletedAt);
  writer.writeString(offsets[2], object.displayName);
  writer.writeString(offsets[3], object.expenseId);
  writer.writeString(offsets[4], object.groupId);
  writer.writeString(offsets[5], object.ownerKey);
  writer.writeString(offsets[6], object.payloadJson);
  writer.writeString(offsets[7], object.recordKey);
  writer.writeDateTime(offsets[8], object.serverUpdatedAt);
  writer.writeDateTime(offsets[9], object.settledAt);
  writer.writeString(offsets[10], object.status);
  writer.writeString(offsets[11], object.userId);
}

ExpenseShareEntity _expenseShareEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ExpenseShareEntity();
  object.amountInMinor = reader.readLongOrNull(offsets[0]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[1]);
  object.displayName = reader.readStringOrNull(offsets[2]);
  object.expenseId = reader.readString(offsets[3]);
  object.groupId = reader.readString(offsets[4]);
  object.id = id;
  object.ownerKey = reader.readString(offsets[5]);
  object.payloadJson = reader.readStringOrNull(offsets[6]);
  object.recordKey = reader.readString(offsets[7]);
  object.serverUpdatedAt = reader.readDateTime(offsets[8]);
  object.settledAt = reader.readDateTimeOrNull(offsets[9]);
  object.status = reader.readStringOrNull(offsets[10]);
  object.userId = reader.readString(offsets[11]);
  return object;
}

P _expenseShareEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    case 9:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 10:
      return (reader.readStringOrNull(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _expenseShareEntityGetId(ExpenseShareEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _expenseShareEntityGetLinks(
  ExpenseShareEntity object,
) {
  return [];
}

void _expenseShareEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ExpenseShareEntity object,
) {
  object.id = id;
}

extension ExpenseShareEntityByIndex on IsarCollection<ExpenseShareEntity> {
  Future<ExpenseShareEntity?> getByRecordKey(String recordKey) {
    return getByIndex(r'recordKey', [recordKey]);
  }

  ExpenseShareEntity? getByRecordKeySync(String recordKey) {
    return getByIndexSync(r'recordKey', [recordKey]);
  }

  Future<bool> deleteByRecordKey(String recordKey) {
    return deleteByIndex(r'recordKey', [recordKey]);
  }

  bool deleteByRecordKeySync(String recordKey) {
    return deleteByIndexSync(r'recordKey', [recordKey]);
  }

  Future<List<ExpenseShareEntity?>> getAllByRecordKey(
    List<String> recordKeyValues,
  ) {
    final values = recordKeyValues.map((e) => [e]).toList();
    return getAllByIndex(r'recordKey', values);
  }

  List<ExpenseShareEntity?> getAllByRecordKeySync(
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

  Future<Id> putByRecordKey(ExpenseShareEntity object) {
    return putByIndex(r'recordKey', object);
  }

  Id putByRecordKeySync(ExpenseShareEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'recordKey', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByRecordKey(List<ExpenseShareEntity> objects) {
    return putAllByIndex(r'recordKey', objects);
  }

  List<Id> putAllByRecordKeySync(
    List<ExpenseShareEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'recordKey', objects, saveLinks: saveLinks);
  }
}

extension ExpenseShareEntityQueryWhereSort
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QWhere> {
  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ExpenseShareEntityQueryWhere
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QWhereClause> {
  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  recordKeyEqualTo(String recordKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'recordKey', value: [recordKey]),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  expenseIdEqualTo(String expenseId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'expenseId', value: [expenseId]),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  expenseIdNotEqualTo(String expenseId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'expenseId',
                lower: [],
                upper: [expenseId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'expenseId',
                lower: [expenseId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'expenseId',
                lower: [expenseId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'expenseId',
                lower: [],
                upper: [expenseId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  groupIdEqualTo(String groupId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'groupId', value: [groupId]),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
  ownerKeyEqualTo(String ownerKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'ownerKey', value: [ownerKey]),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterWhereClause>
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

extension ExpenseShareEntityQueryFilter
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QFilterCondition> {
  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  amountInMinorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'amountInMinor'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  amountInMinorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'amountInMinor'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  amountInMinorEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'amountInMinor', value: value),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  amountInMinorGreaterThan(int? value, {bool include = false}) {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  amountInMinorLessThan(int? value, {bool include = false}) {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  amountInMinorBetween(
    int? lower,
    int? upper, {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'deletedAt'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  deletedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'deletedAt', value: value),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  deletedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  deletedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'deletedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'deletedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'displayName'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'displayName'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'displayName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'displayName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'displayName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'displayName', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'expenseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'expenseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'expenseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'expenseId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'expenseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'expenseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'expenseId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'expenseId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'expenseId', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  expenseIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'expenseId', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  groupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'groupId', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  groupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'groupId', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  ownerKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ownerKey', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  ownerKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ownerKey', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'payloadJson'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'payloadJson'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonGreaterThan(
    String? value, {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonLessThan(
    String? value, {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  payloadJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'payloadJson', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  recordKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'recordKey', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  recordKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'recordKey', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  serverUpdatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'serverUpdatedAt', value: value),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  settledAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'settledAt'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  settledAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'settledAt'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  settledAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'settledAt', value: value),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  settledAtGreaterThan(DateTime? value, {bool include = false}) {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  settledAtLessThan(DateTime? value, {bool include = false}) {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  settledAtBetween(
    DateTime? lower,
    DateTime? upper, {
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

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'status'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'status'),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'status',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'status',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'status',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'status', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'userId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'userId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'userId', value: ''),
      );
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterFilterCondition>
  userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'userId', value: ''),
      );
    });
  }
}

extension ExpenseShareEntityQueryObject
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QFilterCondition> {}

extension ExpenseShareEntityQueryLinks
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QFilterCondition> {}

extension ExpenseShareEntityQuerySortBy
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QSortBy> {
  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByExpenseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByExpenseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByRecordKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByRecordKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByServerUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortBySettledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortBySettledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension ExpenseShareEntityQuerySortThenBy
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QSortThenBy> {
  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'amountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByExpenseId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByExpenseIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'expenseId', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupId', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByPayloadJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByPayloadJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payloadJson', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByRecordKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByRecordKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'recordKey', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByServerUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'serverUpdatedAt', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenBySettledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenBySettledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'settledAt', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QAfterSortBy>
  thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension ExpenseShareEntityQueryWhereDistinct
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct> {
  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'amountInMinor');
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByDisplayName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByExpenseId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'expenseId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByOwnerKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByPayloadJson({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payloadJson', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByRecordKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'recordKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByServerUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'serverUpdatedAt');
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctBySettledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'settledAt');
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByStatus({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QDistinct>
  distinctByUserId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension ExpenseShareEntityQueryProperty
    on QueryBuilder<ExpenseShareEntity, ExpenseShareEntity, QQueryProperty> {
  QueryBuilder<ExpenseShareEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ExpenseShareEntity, int?, QQueryOperations>
  amountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'amountInMinor');
    });
  }

  QueryBuilder<ExpenseShareEntity, DateTime?, QQueryOperations>
  deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<ExpenseShareEntity, String?, QQueryOperations>
  displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<ExpenseShareEntity, String, QQueryOperations>
  expenseIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'expenseId');
    });
  }

  QueryBuilder<ExpenseShareEntity, String, QQueryOperations> groupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupId');
    });
  }

  QueryBuilder<ExpenseShareEntity, String, QQueryOperations>
  ownerKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerKey');
    });
  }

  QueryBuilder<ExpenseShareEntity, String?, QQueryOperations>
  payloadJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payloadJson');
    });
  }

  QueryBuilder<ExpenseShareEntity, String, QQueryOperations>
  recordKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recordKey');
    });
  }

  QueryBuilder<ExpenseShareEntity, DateTime, QQueryOperations>
  serverUpdatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'serverUpdatedAt');
    });
  }

  QueryBuilder<ExpenseShareEntity, DateTime?, QQueryOperations>
  settledAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'settledAt');
    });
  }

  QueryBuilder<ExpenseShareEntity, String?, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }

  QueryBuilder<ExpenseShareEntity, String, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
