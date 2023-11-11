// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SettingsValue _$SettingsValueFromJson(Map<String, dynamic> json) =>
    SettingsValue(
      json['b'] as bool?,
      json['s'] as String?,
      json['i'] as int?,
      (json['d'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$SettingsValueToJson(SettingsValue instance) =>
    <String, dynamic>{
      'b': instance.booleanValue,
      's': instance.stringValue,
      'i': instance.intValue,
      'd': instance.doubleValue,
    };
