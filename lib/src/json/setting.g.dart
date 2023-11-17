// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Setting _$SettingFromJson(Map<String, dynamic> json) => Setting(
      SettingsValue.fromJson(json['v'] as Map<String, dynamic>),
      json['t'] as int? ?? 0,
      (json['p'] as List<dynamic>?)
              ?.map((e) => PercentageOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      (json['r'] as List<dynamic>?)
              ?.map((e) => TargetingRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      json['i'] as String? ?? '',
      json['a'] as String,
      json['salt'] as String,
      (json['segments'] as List<dynamic>)
          .map((e) => Segment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$SettingToJson(Setting instance) => <String, dynamic>{
      'v': instance.settingsValue,
      't': instance.type,
      'p': instance.percentageOptions,
      'r': instance.targetingRules,
      'i': instance.variationId,
      'a': instance.percentageAttribute,
      'salt': instance.salt,
      'segments': instance.segments,
    };
