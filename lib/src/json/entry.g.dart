// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Entry _$EntryFromJson(Map<String, dynamic> json) => Entry(
      Config.fromJson(json['config'] as Map<String, dynamic>),
      json['eTag'] as String,
      DateTime.parse(json['fetchTime'] as String),
    );

Map<String, dynamic> _$EntryToJson(Entry instance) => <String, dynamic>{
      'config': instance.config,
      'eTag': instance.eTag,
      'fetchTime': instance.fetchTime.toIso8601String(),
    };
