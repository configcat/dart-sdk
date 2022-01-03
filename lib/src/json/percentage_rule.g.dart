// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'percentage_rule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RolloutPercentageItem _$RolloutPercentageItemFromJson(
        Map<String, dynamic> json) =>
    RolloutPercentageItem(
      json['v'],
      (json['p'] as num).toDouble(),
      json['i'] as String? ?? '',
    );

Map<String, dynamic> _$RolloutPercentageItemToJson(
        RolloutPercentageItem instance) =>
    <String, dynamic>{
      'v': instance.value,
      'p': instance.percentage,
      'i': instance.variationId,
    };
