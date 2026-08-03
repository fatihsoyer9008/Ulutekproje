// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReceiptEntityCollection on Isar {
  IsarCollection<ReceiptEntity> get receiptEntitys => this.collection();
}

const ReceiptEntitySchema = CollectionSchema(
  name: r'ReceiptEntity',
  id: 7955953532341981086,
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
    r'currency': PropertySchema(
      id: 2,
      name: r'currency',
      type: IsarType.string,
    ),
    r'date': PropertySchema(id: 3, name: r'date', type: IsarType.dateTime),
    r'merchantName': PropertySchema(
      id: 4,
      name: r'merchantName',
      type: IsarType.string,
    ),
    r'rawOcrText': PropertySchema(
      id: 5,
      name: r'rawOcrText',
      type: IsarType.string,
    ),
    r'totalAmountInMinor': PropertySchema(
      id: 6,
      name: r'totalAmountInMinor',
      type: IsarType.long,
    ),
    r'transactionId': PropertySchema(
      id: 7,
      name: r'transactionId',
      type: IsarType.long,
    ),
    r'updatedAt': PropertySchema(
      id: 8,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
  },
  estimateSize: _receiptEntityEstimateSize,
  serialize: _receiptEntitySerialize,
  deserialize: _receiptEntityDeserialize,
  deserializeProp: _receiptEntityDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _receiptEntityGetId,
  getLinks: _receiptEntityGetLinks,
  attach: _receiptEntityAttach,
  version: '3.1.0+1',
);

int _receiptEntityEstimateSize(
  ReceiptEntity object,
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
  bytesCount += 3 + object.currency.length * 3;
  {
    final value = object.merchantName;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.rawOcrText;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _receiptEntitySerialize(
  ReceiptEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.category);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeString(offsets[2], object.currency);
  writer.writeDateTime(offsets[3], object.date);
  writer.writeString(offsets[4], object.merchantName);
  writer.writeString(offsets[5], object.rawOcrText);
  writer.writeLong(offsets[6], object.totalAmountInMinor);
  writer.writeLong(offsets[7], object.transactionId);
  writer.writeDateTime(offsets[8], object.updatedAt);
}

ReceiptEntity _receiptEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReceiptEntity();
  object.category = reader.readStringOrNull(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.currency = reader.readString(offsets[2]);
  object.date = reader.readDateTimeOrNull(offsets[3]);
  object.id = id;
  object.merchantName = reader.readStringOrNull(offsets[4]);
  object.rawOcrText = reader.readStringOrNull(offsets[5]);
  object.totalAmountInMinor = reader.readLong(offsets[6]);
  object.transactionId = reader.readLongOrNull(offsets[7]);
  object.updatedAt = reader.readDateTime(offsets[8]);
  return object;
}

P _receiptEntityDeserializeProp<P>(
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
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
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

Id _receiptEntityGetId(ReceiptEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _receiptEntityGetLinks(ReceiptEntity object) {
  return [];
}

void _receiptEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  ReceiptEntity object,
) {
  object.id = id;
}

extension ReceiptEntityQueryWhereSort
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QWhere> {
  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ReceiptEntityQueryWhere
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QWhereClause> {
  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterWhereClause> idBetween(
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
}

extension ReceiptEntityQueryFilter
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QFilterCondition> {
  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  categoryIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'category'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  categoryIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'category'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  categoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  categoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'category', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  currencyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'currency', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  currencyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'currency', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  dateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'date'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  dateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'date'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition> dateEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'date', value: value),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  dateGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'date',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  dateLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'date',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition> dateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'date',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'merchantName'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'merchantName'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'merchantName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'merchantName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'merchantName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'merchantName',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'merchantName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'merchantName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'merchantName',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'merchantName',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'merchantName', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  merchantNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'merchantName', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'rawOcrText'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'rawOcrText'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'rawOcrText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'rawOcrText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'rawOcrText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'rawOcrText',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'rawOcrText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'rawOcrText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'rawOcrText',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'rawOcrText',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'rawOcrText', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  rawOcrTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'rawOcrText', value: ''),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  totalAmountInMinorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'totalAmountInMinor', value: value),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  transactionIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'transactionId'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  transactionIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'transactionId'),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  transactionIdEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'transactionId', value: value),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  transactionIdGreaterThan(int? value, {bool include = false}) {
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  transactionIdLessThan(int? value, {bool include = false}) {
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  transactionIdBetween(
    int? lower,
    int? upper, {
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
  updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'updatedAt', value: value),
      );
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterFilterCondition>
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

extension ReceiptEntityQueryObject
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QFilterCondition> {}

extension ReceiptEntityQueryLinks
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QFilterCondition> {}

extension ReceiptEntityQuerySortBy
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QSortBy> {
  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> sortByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> sortByCurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByCurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> sortByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> sortByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByMerchantName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'merchantName', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByMerchantNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'merchantName', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> sortByRawOcrText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawOcrText', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByRawOcrTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawOcrText', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByTotalAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByTransactionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ReceiptEntityQuerySortThenBy
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QSortThenBy> {
  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'category', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByCurrency() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByCurrencyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currency', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'date', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByMerchantName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'merchantName', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByMerchantNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'merchantName', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByRawOcrText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawOcrText', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByRawOcrTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawOcrText', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByTotalAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'totalAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByTransactionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'transactionId', Sort.desc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QAfterSortBy>
  thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension ReceiptEntityQueryWhereDistinct
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> {
  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> distinctByCategory({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'category', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> distinctByCurrency({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'currency', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> distinctByDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'date');
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> distinctByMerchantName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'merchantName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> distinctByRawOcrText({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawOcrText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct>
  distinctByTotalAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'totalAmountInMinor');
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct>
  distinctByTransactionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'transactionId');
    });
  }

  QueryBuilder<ReceiptEntity, ReceiptEntity, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension ReceiptEntityQueryProperty
    on QueryBuilder<ReceiptEntity, ReceiptEntity, QQueryProperty> {
  QueryBuilder<ReceiptEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ReceiptEntity, String?, QQueryOperations> categoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'category');
    });
  }

  QueryBuilder<ReceiptEntity, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<ReceiptEntity, String, QQueryOperations> currencyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currency');
    });
  }

  QueryBuilder<ReceiptEntity, DateTime?, QQueryOperations> dateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'date');
    });
  }

  QueryBuilder<ReceiptEntity, String?, QQueryOperations>
  merchantNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'merchantName');
    });
  }

  QueryBuilder<ReceiptEntity, String?, QQueryOperations> rawOcrTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawOcrText');
    });
  }

  QueryBuilder<ReceiptEntity, int, QQueryOperations>
  totalAmountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'totalAmountInMinor');
    });
  }

  QueryBuilder<ReceiptEntity, int?, QQueryOperations> transactionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'transactionId');
    });
  }

  QueryBuilder<ReceiptEntity, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
