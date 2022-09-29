// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'percentage_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PercentageRule _$PercentageRuleFromJson(Map<String, dynamic> json) =>
    PercentageRule(
      json['v'],
      (json['p'] as num).toDouble(),
      json['i'] as String? ?? '',
    );

Map<String, dynamic> _$PercentageRuleToJson(PercentageRule instance) =>
    <String, dynamic>{
      'v': instance.value,
      'p': instance.percentage,
      'i': instance.variationId,
    };
