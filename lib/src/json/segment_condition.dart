import 'package:json_annotation/json_annotation.dart';


part 'segment_condition.g.dart';
@JsonSerializable()
class SegmentCondition {

  @JsonKey(name: 's')
  final int? segmentIndex;

  /// The operator used in the comparison.
  ///
  /// 0  -> 'IS IN SEGMENT',
  /// 1  -> 'IS NOT IN SEGMENT',
  @JsonKey(name: 'c', defaultValue: 0)
  final int segmentComparator;

  SegmentCondition(this.segmentIndex, this.segmentComparator);

  factory SegmentCondition.fromJson(Map<String, dynamic> json) => _$SegmentConditionFromJson(json);
  Map<String, dynamic> toJson() => _$SegmentConditionToJson(this);
}