// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Config _$ConfigFromJson(Map<String, dynamic> json) => Config(
      Preferences.fromJson(json['p'] as Map<String, dynamic>),
      (json['f'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, Setting.fromJson(e as Map<String, dynamic>)),
      ),
      (json['s'] as List<dynamic>?)
              ?.map((e) => Segment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$ConfigToJson(Config instance) => <String, dynamic>{
      'p': instance.preferences,
      'f': instance.entries,
      's': instance.segments,
    };
