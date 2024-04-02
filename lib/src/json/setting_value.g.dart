// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SettingValue _$SettingValueFromJson(Map<String, dynamic> json) => SettingValue(
      json['b'] as bool?,
      json['s'] as String?,
      json['i'] as int?,
      (json['d'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SettingValueToJson(SettingValue instance) =>
    <String, dynamic>{
      'b': instance.booleanValue,
      's': instance.stringValue,
      'i': instance.intValue,
      'd': instance.doubleValue,
    };
