import 'package:json_annotation/json_annotation.dart';

import 'user_condition.dart';

part 'segment.g.dart';

//TODO add CondotionAccessor?
@JsonSerializable()
class Segment {

  @JsonKey(name: 'n')
  final String? name;

  @JsonKey(name: 'r')
  final List<UserCondition> segmentRules;

  Segment(this.name, this.segmentRules);

  factory Segment.fromJson(Map<String, dynamic> json) => _$SegmentFromJson(json);
  Map<String, dynamic> toJson() => _$SegmentToJson(this);

}