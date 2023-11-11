// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserCondition _$UserConditionFromJson(Map<String, dynamic> json) =>
    UserCondition(
      json['a'] as String,
      json['c'] as int,
      json['s'] as String?,
      (json['d'] as num?)?.toDouble(),
      (json['l'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$UserConditionToJson(UserCondition instance) =>
    <String, dynamic>{
      'a': instance.comparisonAttribute,
      'c': instance.comparator,
      's': instance.stringValue,
      'd': instance.doubleValue,
      'l': instance.stringArrayValue,
    };
