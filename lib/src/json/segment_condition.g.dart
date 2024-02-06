// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'segment_condition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SegmentCondition _$SegmentConditionFromJson(Map<String, dynamic> json) =>
    SegmentCondition(
      json['s'] as int,
      json['c'] as int,
    );

Map<String, dynamic> _$SegmentConditionToJson(SegmentCondition instance) =>
    <String, dynamic>{
      's': instance.segmentIndex,
      'c': instance.segmentComparator,
    };
