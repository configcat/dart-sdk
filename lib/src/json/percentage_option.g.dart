// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'percentage_option.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PercentageOption _$PercentageOptionFromJson(Map<String, dynamic> json) =>
    PercentageOption(
      SettingValue.fromJson(json['v'] as Map<String, dynamic>),
      (json['p'] as num?)?.toDouble() ?? 0,
      json['i'] as String?,
    );

Map<String, dynamic> _$PercentageOptionToJson(PercentageOption instance) =>
    <String, dynamic>{
      'v': instance.settingValue,
      'p': instance.percentage,
      'i': instance.variationId,
    };
