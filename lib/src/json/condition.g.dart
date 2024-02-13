// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Condition _$ConditionFromJson(Map<String, dynamic> json) => Condition(
      json['u'] == null
          ? null
          : UserCondition.fromJson(json['u'] as Map<String, dynamic>),
      json['s'] == null
          ? null
          : SegmentCondition.fromJson(json['s'] as Map<String, dynamic>),
      json['p'] == null
          ? null
          : PrerequisiteFlagCondition.fromJson(
              json['p'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ConditionToJson(Condition instance) => <String, dynamic>{
      'u': instance.userCondition,
      's': instance.segmentCondition,
      'p': instance.prerequisiteFlagCondition,
    };
