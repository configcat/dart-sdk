// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'served_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServedValue _$ServedValueFromJson(Map<String, dynamic> json) => ServedValue(
      SettingValue.fromJson(json['v'] as Map<String, dynamic>),
      json['i'] as String?,
    );

Map<String, dynamic> _$ServedValueToJson(ServedValue instance) =>
    <String, dynamic>{
      'v': instance.settingValue,
      'i': instance.variationId,
    };
