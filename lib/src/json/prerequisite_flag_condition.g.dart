// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prerequisite_flag_condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrerequisiteFlagCondition _$PrerequisiteFlagConditionFromJson(
        Map<String, dynamic> json) =>
    PrerequisiteFlagCondition(
      json['f'] as String,
      json['c'] as int,
      json['v'] == null
          ? null
          : SettingValue.fromJson(json['v'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PrerequisiteFlagConditionToJson(
        PrerequisiteFlagCondition instance) =>
    <String, dynamic>{
      'f': instance.prerequisiteFlagKey,
      'c': instance.prerequisiteComparator,
      'v': instance.value,
    };
