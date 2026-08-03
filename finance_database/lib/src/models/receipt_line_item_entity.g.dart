// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_line_item_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReceiptLineItemEntityCollection on Isar {
  IsarCollection<ReceiptLineItemEntity> get receiptLineItemEntitys =>
      this.collection();
}

const ReceiptLineItemEntitySchema = CollectionSchema(
  name: r'ReceiptLineItemEntity',
  id: -9022474038160712649,
  properties: {
    r'category': PropertySchema(
      id: 0,
      name: r'category',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(id: 2, name: r'name', type: IsarType.string),
    r'quantityInMillis': PropertySchema(
      id: 3,
      name: r'quantityInMillis',
      type: IsarType.long,
    ),
    r'receiptId': PropertySchema(
      id: 4,
      name: r'receiptId',
      type: IsarType.long,
    ),
    r'taxRateInBasisPoints': PropertySchema(
      id: 5,
      name: r'taxRateInBasisPoints',
      type: IsarType.long,
    ),
    r'totalAmountInMinor': PropertySchema(
      id: 6,
      name: r'totalAmountInMinor',
      type: IsarType.long,
    ),
    r'unitPriceInMinor': PropertySchema(
      id: 7,
      name: r'unitPriceInMinor',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },
  estimateSize: _receiptLineItemEntityEstimateSize,
  serialize: _receiptLineItemEntitySerialize,
  deserialize: _receiptLineItemEntityDeserialize,
  deserializeProp: _receiptLineItemEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'receiptId': IndexSchema(
      id: 5666094434830883054,
      name: r'receiptId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'receiptId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},
  getId: _receiptLineItemEntityGetId,
  getLinks: _receiptLineItemEntityGetLinks,
  attach: _receiptLineItemEntityAttach,
  version: '3.1.0+1',
);

int _receiptLineItemEntityEstimateSize(
  ReceiptLineItemEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.category;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  return bytesCount;
}

void _receiptLineItemEntitySerialize(
  ReceiptLineItemEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.category);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.name);
  writer.writeLong(offsets[3], object.quantityInMillis);
  writer.writeLong(offsets[4], object.receiptId);
  writer.writeLong(offsets[5], object.taxRateInBasisPoints);
  writer.writeLong(offsets[6], object.totalAmountInMinor);
  writer.writeLong(offsets[7], object.unitPriceInMinor);
  writer.writeDateTime(offsets[8], object.updatedAt);
}

ReceiptLineItemEntity _receiptLineItemEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReceiptLineItemEntity();
  object.category = reader.readStringOrNull(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.id = id;
  object.name = reader.readString(offsets[2]);
  object.quantityInMillis = reader.readLong(offsets[3]);
  object.receiptId = reader.readLong(offsets[4]);
  object.taxRateInBasisPoints = reader.readLongOrNull(offsets[5]);
  object.totalAmountInMinor = reader.readLong(offsets[6]);
  object.unitPriceInMinor = reader.readLongOrNull(offsets[7]);
  object.updatedAt = reader.readDateTime(offsets[8]);
  return object;
}

P _receiptLineItemEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _receiptLineItemEntityGetId(ReceiptLineItemEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _receiptLineItemEntityGetLinks(
  ReceiptLineItemEntity object,
) {
  return [];
}

void _receiptLineItemEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ReceiptLineItemEntity object,
) {
  object.id = id;
}

extension ReceiptLineItemEntityQueryWhereSort
    on QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QWhere> {
  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhere>
  anyReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'receiptId'),
      );
    });
  }
}

extension ReceiptLineItemEntityQueryWhere
    on
        QueryBuilder<
          ReceiptLineItemEntity,
          ReceiptLineItemEntity,
          QWhereClause
        > {
  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
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

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
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

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  receiptIdEqualTo(int receiptId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'receiptId', value: [receiptId]),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  receiptIdNotEqualTo(int receiptId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'receiptId',
                lower: [],
                upper: [receiptId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'receiptId',
                lower: [receiptId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'receiptId',
                lower: [receiptId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'receiptId',
                lower: [],
                upper: [receiptId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  receiptIdGreaterThan(int receiptId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'receiptId',
          lower: [receiptId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  receiptIdLessThan(int receiptId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'receiptId',
          lower: [],
          upper: [receiptId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  receiptIdBetween(
    int lowerReceiptId,
    int upperReceiptId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'receiptId',
          lower: [lowerReceiptId],
          includeLower: includeLower,
          upper: [upperReceiptId],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ReceiptLineItemEntityQueryFilter
    on
        QueryBuilder<
          ReceiptLineItemEntity,
          ReceiptLineItemEntity,
          QFilterCondition
        > {
  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'category'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'category'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'category',
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'category',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'category',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
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
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityInMillisEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'quantityInMillis', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityInMillisGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'quantityInMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityInMillisLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'quantityInMillis',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityInMillisBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'quantityInMillis',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  receiptIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'receiptId', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  receiptIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'receiptId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  receiptIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'receiptId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  receiptIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'receiptId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateInBasisPointsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'taxRateInBasisPoints'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateInBasisPointsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'taxRateInBasisPoints'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateInBasisPointsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'taxRateInBasisPoints',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateInBasisPointsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'taxRateInBasisPoints',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateInBasisPointsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'taxRateInBasisPoints',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateInBasisPointsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'taxRateInBasisPoints',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  totalAmountInMinorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalAmountInMinor', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  totalAmountInMinorGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'totalAmountInMinor',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  totalAmountInMinorLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'totalAmountInMinor',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  totalAmountInMinorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'totalAmountInMinor',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  unitPriceInMinorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'unitPriceInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  unitPriceInMinorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'unitPriceInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  unitPriceInMinorEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'unitPriceInMinor', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  unitPriceInMinorGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'unitPriceInMinor',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  unitPriceInMinorLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'unitPriceInMinor',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  unitPriceInMinorBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'unitPriceInMinor',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  updatedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  updatedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'updatedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'updatedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension ReceiptLineItemEntityQueryObject
    on
        QueryBuilder<
          ReceiptLineItemEntity,
          ReceiptLineItemEntity,
          QFilterCondition
        > {}

extension ReceiptLineItemEntityQueryLinks
    on
        QueryBuilder<
          ReceiptLineItemEntity,
          ReceiptLineItemEntity,
          QFilterCondition
        > {}

extension ReceiptLineItemEntityQuerySortBy
    on QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QSortBy> {
  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByQuantityInMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantityInMillis', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByQuantityInMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantityInMillis', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTaxRateInBasisPoints() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRateInBasisPoints', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTaxRateInBasisPointsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRateInBasisPoints', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTotalAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByUnitPriceInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitPriceInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByUnitPriceInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitPriceInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ReceiptLineItemEntityQuerySortThenBy
    on QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QSortThenBy> {
  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByQuantityInMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantityInMillis', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByQuantityInMillisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantityInMillis', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByReceiptIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'receiptId', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTaxRateInBasisPoints() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRateInBasisPoints', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTaxRateInBasisPointsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRateInBasisPoints', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTotalAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByUnitPriceInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitPriceInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByUnitPriceInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'unitPriceInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ReceiptLineItemEntityQueryWhereDistinct
    on QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct> {
  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByCategory({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByQuantityInMillis() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quantityInMillis');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiptId');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByTaxRateInBasisPoints() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taxRateInBasisPoints');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalAmountInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByUnitPriceInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitPriceInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension ReceiptLineItemEntityQueryProperty
    on
        QueryBuilder<
          ReceiptLineItemEntity,
          ReceiptLineItemEntity,
          QQueryProperty
        > {
  QueryBuilder<ReceiptLineItemEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, String?, QQueryOperations>
  categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, DateTime, QQueryOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int, QQueryOperations>
  quantityInMillisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quantityInMillis');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int, QQueryOperations>
  receiptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiptId');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int?, QQueryOperations>
  taxRateInBasisPointsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taxRateInBasisPoints');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int, QQueryOperations>
  totalAmountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalAmountInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int?, QQueryOperations>
  unitPriceInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitPriceInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, DateTime, QQueryOperations>
  updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
