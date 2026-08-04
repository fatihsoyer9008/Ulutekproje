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
    r'name': PropertySchema(id: 1, name: r'name', type: IsarType.string),
    r'position': PropertySchema(id: 2, name: r'position', type: IsarType.long),
    r'priceInMinor': PropertySchema(
      id: 3,
      name: r'priceInMinor',
      type: IsarType.long,
    ),
    r'quantity': PropertySchema(
      id: 4,
      name: r'quantity',
      type: IsarType.double,
    ),
    r'receiptId': PropertySchema(
      id: 5,
      name: r'receiptId',
      type: IsarType.long,
    ),
    r'taxAmountInMinor': PropertySchema(
      id: 6,
      name: r'taxAmountInMinor',
      type: IsarType.long,
    ),
    r'taxRate': PropertySchema(id: 7, name: r'taxRate', type: IsarType.double),
    r'totalAmountInMinor': PropertySchema(
      id: 8,
      name: r'totalAmountInMinor',
      type: IsarType.long,
    ),
    r'transactionId': PropertySchema(
      id: 9,
      name: r'transactionId',
      type: IsarType.long,
    ),
    r'unitPriceInMinor': PropertySchema(
      id: 10,
      name: r'unitPriceInMinor',
      type: IsarType.long,
    ),
  },
  estimateSize: _receiptLineItemEntityEstimateSize,
  serialize: _receiptLineItemEntitySerialize,
  deserialize: _receiptLineItemEntityDeserialize,
  deserializeProp: _receiptLineItemEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'transactionId': IndexSchema(
      id: 8561542235958051982,
      name: r'transactionId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'transactionId',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
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
  writer.writeString(offsets[1], object.name);
  writer.writeLong(offsets[2], object.position);
  writer.writeLong(offsets[3], object.priceInMinor);
  writer.writeDouble(offsets[4], object.quantity);
  writer.writeLong(offsets[5], object.receiptId);
  writer.writeLong(offsets[6], object.taxAmountInMinor);
  writer.writeDouble(offsets[7], object.taxRate);
  writer.writeLong(offsets[8], object.totalAmountInMinor);
  writer.writeLong(offsets[9], object.transactionId);
  writer.writeLong(offsets[10], object.unitPriceInMinor);
}

ReceiptLineItemEntity _receiptLineItemEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReceiptLineItemEntity();
  object.category = reader.readStringOrNull(offsets[0]);
  object.id = id;
  object.name = reader.readString(offsets[1]);
  object.position = reader.readLong(offsets[2]);
  object.priceInMinor = reader.readLongOrNull(offsets[3]);
  object.quantity = reader.readDoubleOrNull(offsets[4]);
  object.receiptId = reader.readLong(offsets[5]);
  object.taxAmountInMinor = reader.readLongOrNull(offsets[6]);
  object.taxRate = reader.readDoubleOrNull(offsets[7]);
  object.totalAmountInMinor = reader.readLongOrNull(offsets[8]);
  object.transactionId = reader.readLong(offsets[9]);
  object.unitPriceInMinor = reader.readLongOrNull(offsets[10]);
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
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (reader.readDoubleOrNull(offset)) as P;
    case 8:
      return (reader.readLongOrNull(offset)) as P;
    case 9:
      return (reader.readLong(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
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
  anyTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'transactionId'),
      );
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
  transactionIdEqualTo(int transactionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'transactionId',
          value: [transactionId],
        ),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  transactionIdNotEqualTo(int transactionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'transactionId',
                lower: [],
                upper: [transactionId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'transactionId',
                lower: [transactionId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'transactionId',
                lower: [transactionId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'transactionId',
                lower: [],
                upper: [transactionId],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  transactionIdGreaterThan(int transactionId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'transactionId',
          lower: [transactionId],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  transactionIdLessThan(int transactionId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'transactionId',
          lower: [],
          upper: [transactionId],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterWhereClause>
  transactionIdBetween(
    int lowerTransactionId,
    int upperTransactionId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'transactionId',
          lower: [lowerTransactionId],
          includeLower: includeLower,
          upper: [upperTransactionId],
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
  positionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'position', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  positionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'position',
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
  positionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'position',
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
  positionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'position',
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
  priceInMinorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'priceInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  priceInMinorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'priceInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  priceInMinorEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'priceInMinor', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  priceInMinorGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'priceInMinor',
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
  priceInMinorLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'priceInMinor',
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
  priceInMinorBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'priceInMinor',
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
  quantityIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'quantity'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'quantity'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'quantity',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'quantity',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'quantity',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  quantityBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'quantity',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
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
  taxAmountInMinorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'taxAmountInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxAmountInMinorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'taxAmountInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxAmountInMinorEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'taxAmountInMinor', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxAmountInMinorGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'taxAmountInMinor',
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
  taxAmountInMinorLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'taxAmountInMinor',
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
  taxAmountInMinorBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'taxAmountInMinor',
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
  taxRateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'taxRate'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'taxRate'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'taxRate',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'taxRate',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'taxRate',
          value: value,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  taxRateBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'taxRate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  totalAmountInMinorIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'totalAmountInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  totalAmountInMinorIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'totalAmountInMinor'),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  totalAmountInMinorEqualTo(int? value) {
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
  totalAmountInMinorGreaterThan(int? value, {bool include = false}) {
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
  totalAmountInMinorLessThan(int? value, {bool include = false}) {
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
    int? lower,
    int? upper, {
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
  transactionIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'transactionId', value: value),
      );
    });
  }

  QueryBuilder<
    ReceiptLineItemEntity,
    ReceiptLineItemEntity,
    QAfterFilterCondition
  >
  transactionIdGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'transactionId',
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
  transactionIdLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'transactionId',
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
  transactionIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'transactionId',
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
  sortByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByPriceInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priceInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByPriceInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priceInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
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
  sortByTaxAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTaxAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTaxRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRate', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTaxRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRate', Sort.desc);
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
  sortByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  sortByTransactionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.desc);
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
  thenByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'position', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByPriceInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priceInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByPriceInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'priceInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByQuantityDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'quantity', Sort.desc);
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
  thenByTaxAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTaxAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTaxRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRate', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTaxRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taxRate', Sort.desc);
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
  thenByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.asc);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QAfterSortBy>
  thenByTransactionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.desc);
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
  distinctByName({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'position');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByPriceInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'priceInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByQuantity() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'quantity');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByReceiptId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'receiptId');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByTaxAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taxAmountInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByTaxRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taxRate');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalAmountInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'transactionId');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, ReceiptLineItemEntity, QDistinct>
  distinctByUnitPriceInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'unitPriceInMinor');
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

  QueryBuilder<ReceiptLineItemEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int, QQueryOperations>
  positionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'position');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int?, QQueryOperations>
  priceInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'priceInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, double?, QQueryOperations>
  quantityProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'quantity');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int, QQueryOperations>
  receiptIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'receiptId');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int?, QQueryOperations>
  taxAmountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taxAmountInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, double?, QQueryOperations>
  taxRateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taxRate');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int?, QQueryOperations>
  totalAmountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalAmountInMinor');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int, QQueryOperations>
  transactionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'transactionId');
    });
  }

  QueryBuilder<ReceiptLineItemEntity, int?, QQueryOperations>
  unitPriceInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'unitPriceInMinor');
    });
  }
}
