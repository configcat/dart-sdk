// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Preferences _$PreferencesFromJson(Map<String, dynamic> json) => Preferences(
      json['u'] as String,
      json['r'] as int? ?? 0,
      json['s'] as String?,
    );

Map<String, dynamic> _$PreferencesToJson(Preferences instance) =>
    <String, dynamic>{
      'u': instance.baseUrl,
      'r': instance.redirect,
      's': instance.salt,
    };
