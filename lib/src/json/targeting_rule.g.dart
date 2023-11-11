// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'targeting_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TargetingRule _$TargetingRuleFromJson(Map<String, dynamic> json) =>
    TargetingRule(
      (json['c'] as List<dynamic>?)
          ?.map((e) => Condition.fromJson(e as Map<String, dynamic>))
          .toList(),
      (json['p'] as List<dynamic>?)
          ?.map((e) => PercentageOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      ServedValue.fromJson(json['s'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TargetingRuleToJson(TargetingRule instance) =>
    <String, dynamic>{
      'c': instance.conditions,
      'p': instance.percentageOptions,
      's': instance.servedValue,
    };
