// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Setting _$SettingFromJson(Map<String, dynamic> json) => Setting(
      json['v'],
      json['t'] as int? ?? 0,
      (json['p'] as List<dynamic>?)
              ?.map((e) => PercentageRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      (json['r'] as List<dynamic>?)
              ?.map((e) => RolloutRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      json['i'] as String? ?? '',
    );

Map<String, dynamic> _$SettingToJson(Setting instance) => <String, dynamic>{
      'v': instance.value,
      't': instance.type,
      'p': instance.percentageItems,
      'r': instance.rolloutRules,
      'i': instance.variationId,
    };
