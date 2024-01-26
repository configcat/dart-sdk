import 'package:json_annotation/json_annotation.dart';

part 'segment_condition.g.dart';

/// Describes a condition that is based on a segment.
@JsonSerializable()
class SegmentCondition {

  /// The index of the segment that the condition is based on.
  @JsonKey(name: 's')
  final int segmentIndex;

  /// The operator which defines the expected result of the evaluation of the segment.
  @JsonKey(name: 'c', defaultValue: 0)
  final int segmentComparator;

  SegmentCondition(this.segmentIndex, this.segmentComparator);

  factory SegmentCondition.fromJson(Map<String, dynamic> json) =>
      _$SegmentConditionFromJson(json);
  Map<String, dynamic> toJson() => _$SegmentConditionToJson(this);
}
