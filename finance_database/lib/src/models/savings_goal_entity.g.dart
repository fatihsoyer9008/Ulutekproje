// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_goal_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSavingsGoalEntityCollection on Isar {
  IsarCollection<SavingsGoalEntity> get savingsGoalEntitys => this.collection();
}

const SavingsGoalEntitySchema = CollectionSchema(
  name: r'SavingsGoalEntity',
  id: -6731261710927702512,
  properties: {
    r'colorHex': PropertySchema(
      id: 0,
      name: r'colorHex',
      type: IsarType.string,
    ),
    r'createdAt': PropertySchema(
      id: 1,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'currentAmountInMinor': PropertySchema(
      id: 2,
      name: r'currentAmountInMinor',
      type: IsarType.long,
    ),
    r'description': PropertySchema(
      id: 3,
      name: r'description',
      type: IsarType.string,
    ),
    r'iconCodePoint': PropertySchema(
      id: 4,
      name: r'iconCodePoint',
      type: IsarType.long,
    ),
    r'ownerKey': PropertySchema(
      id: 5,
      name: r'ownerKey',
      type: IsarType.string,
    ),
    r'targetAmountInMinor': PropertySchema(
      id: 6,
      name: r'targetAmountInMinor',
      type: IsarType.long,
    ),
    r'targetDate': PropertySchema(
      id: 7,
      name: r'targetDate',
      type: IsarType.dateTime,
    ),
    r'title': PropertySchema(
      id: 8,
      name: r'title',
      type: IsarType.string,
    )
  },
  estimateSize: _savingsGoalEntityEstimateSize,
  serialize: _savingsGoalEntitySerialize,
  deserialize: _savingsGoalEntityDeserialize,
  deserializeProp: _savingsGoalEntityDeserializeProp,
  idName: r'id',
  indexes: {
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
  getId: _savingsGoalEntityGetId,
  getLinks: _savingsGoalEntityGetLinks,
  attach: _savingsGoalEntityAttach,
  version: '3.1.0+1',
);

int _savingsGoalEntityEstimateSize(
  SavingsGoalEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.colorHex;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.ownerKey.length * 3;
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _savingsGoalEntitySerialize(
  SavingsGoalEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.colorHex);
  writer.writeDateTime(offsets[1], object.createdAt);
  writer.writeLong(offsets[2], object.currentAmountInMinor);
  writer.writeString(offsets[3], object.description);
  writer.writeLong(offsets[4], object.iconCodePoint);
  writer.writeString(offsets[5], object.ownerKey);
  writer.writeLong(offsets[6], object.targetAmountInMinor);
  writer.writeDateTime(offsets[7], object.targetDate);
  writer.writeString(offsets[8], object.title);
}

SavingsGoalEntity _savingsGoalEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SavingsGoalEntity();
  object.colorHex = reader.readStringOrNull(offsets[0]);
  object.createdAt = reader.readDateTime(offsets[1]);
  object.currentAmountInMinor = reader.readLong(offsets[2]);
  object.description = reader.readStringOrNull(offsets[3]);
  object.iconCodePoint = reader.readLongOrNull(offsets[4]);
  object.id = id;
  object.ownerKey = reader.readString(offsets[5]);
  object.targetAmountInMinor = reader.readLong(offsets[6]);
  object.targetDate = reader.readDateTimeOrNull(offsets[7]);
  object.title = reader.readString(offsets[8]);
  return object;
}

P _savingsGoalEntityDeserializeProp<P>(
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
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readLongOrNull(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _savingsGoalEntityGetId(SavingsGoalEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _savingsGoalEntityGetLinks(
    SavingsGoalEntity object) {
  return [];
}

void _savingsGoalEntityAttach(
    IsarCollection<dynamic> col, Id id, SavingsGoalEntity object) {
  object.id = id;
}

extension SavingsGoalEntityQueryWhereSort
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QWhere> {
  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SavingsGoalEntityQueryWhere
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QWhereClause> {
  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhereClause>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhereClause>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhereClause>
      ownerKeyEqualTo(String ownerKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'ownerKey',
        value: [ownerKey],
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterWhereClause>
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

extension SavingsGoalEntityQueryFilter
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QFilterCondition> {
  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'colorHex',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'colorHex',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'colorHex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'colorHex',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'colorHex',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'colorHex',
        value: '',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      colorHexIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'colorHex',
        value: '',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      currentAmountInMinorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'currentAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      currentAmountInMinorGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'currentAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      currentAmountInMinorLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'currentAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      currentAmountInMinorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'currentAmountInMinor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      iconCodePointIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'iconCodePoint',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      iconCodePointIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'iconCodePoint',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      iconCodePointEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'iconCodePoint',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      iconCodePointGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'iconCodePoint',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      iconCodePointLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'iconCodePoint',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      iconCodePointBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'iconCodePoint',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      ownerKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'ownerKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      ownerKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'ownerKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      ownerKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'ownerKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      ownerKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'ownerKey',
        value: '',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetAmountInMinorEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetAmountInMinorGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetAmountInMinorLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetAmountInMinor',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetAmountInMinorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetAmountInMinor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetDateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'targetDate',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetDateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'targetDate',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetDateEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetDate',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetDateGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetDate',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetDateLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetDate',
        value: value,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      targetDateBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetDate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
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

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }
}

extension SavingsGoalEntityQueryObject
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QFilterCondition> {}

extension SavingsGoalEntityQueryLinks
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QFilterCondition> {}

extension SavingsGoalEntityQuerySortBy
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QSortBy> {
  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByColorHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByColorHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByCurrentAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByCurrentAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByIconCodePoint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconCodePoint', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByIconCodePointDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconCodePoint', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByTargetAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByTargetAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByTargetDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByTargetDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension SavingsGoalEntityQuerySortThenBy
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QSortThenBy> {
  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByColorHex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByColorHexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'colorHex', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByCurrentAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByCurrentAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'currentAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByIconCodePoint() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconCodePoint', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByIconCodePointDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'iconCodePoint', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByOwnerKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByOwnerKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ownerKey', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByTargetAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAmountInMinor', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByTargetAmountInMinorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetAmountInMinor', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByTargetDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByTargetDateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetDate', Sort.desc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension SavingsGoalEntityQueryWhereDistinct
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct> {
  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByColorHex({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'colorHex', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByCurrentAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'currentAmountInMinor');
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByDescription({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByIconCodePoint() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'iconCodePoint');
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByOwnerKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ownerKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByTargetAmountInMinor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetAmountInMinor');
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct>
      distinctByTargetDate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetDate');
    });
  }

  QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension SavingsGoalEntityQueryProperty
    on QueryBuilder<SavingsGoalEntity, SavingsGoalEntity, QQueryProperty> {
  QueryBuilder<SavingsGoalEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SavingsGoalEntity, String?, QQueryOperations>
      colorHexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'colorHex');
    });
  }

  QueryBuilder<SavingsGoalEntity, DateTime, QQueryOperations>
      createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<SavingsGoalEntity, int, QQueryOperations>
      currentAmountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'currentAmountInMinor');
    });
  }

  QueryBuilder<SavingsGoalEntity, String?, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<SavingsGoalEntity, int?, QQueryOperations>
      iconCodePointProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'iconCodePoint');
    });
  }

  QueryBuilder<SavingsGoalEntity, String, QQueryOperations> ownerKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ownerKey');
    });
  }

  QueryBuilder<SavingsGoalEntity, int, QQueryOperations>
      targetAmountInMinorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetAmountInMinor');
    });
  }

  QueryBuilder<SavingsGoalEntity, DateTime?, QQueryOperations>
      targetDateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetDate');
    });
  }

  QueryBuilder<SavingsGoalEntity, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}
