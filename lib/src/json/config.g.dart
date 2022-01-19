// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Config _$ConfigFromJson(Map<String, dynamic> json) => Config(
      json['p'] == null
          ? null
          : Preferences.fromJson(json['p'] as Map<String, dynamic>),
      (json['f'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Setting.fromJson(e as Map<String, dynamic>)),
      ),
      json['e'] as String? ?? '',
      json['t'] as int? ?? -1,
    );

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
      'p': instance.preferences,
      'f': instance.entries,
      'e': instance.eTag,
      't': instance.timeStamp,
    };
