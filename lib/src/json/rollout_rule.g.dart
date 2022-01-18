// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rollout_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RolloutRule _$RolloutRuleFromJson(Map<String, dynamic> json) => RolloutRule(
      json['v'],
      json['a'] as String,
      json['t'] as int,
      json['c'] as String,
      json['i'] as String? ?? '',
    );

Map<String, dynamic> _$RolloutRuleToJson(RolloutRule instance) =>
    <String, dynamic>{
      'v': instance.value,
      'a': instance.comparisonAttribute,
      't': instance.comparator,
      'c': instance.comparisonValue,
      'i': instance.variationId,
    };
